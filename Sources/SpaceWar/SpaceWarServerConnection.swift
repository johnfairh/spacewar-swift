//
//  SpaceWarServerConnection.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

typealias ClientToken = FakeNetToken

/// Component of SpaceWarServer to manage a set of connected clients, abstracting
/// network access and `FAKE_NET` stuff.
final class SpaceWarServerConnection {
    let steam: SteamGameServerAPI
    let tickSource: TickSource
    let serverName: String
    let listenSocket: HSteamListenSocket?
    let pollGroup: HSteamNetPollGroup?

    /// Server callback to check it's OK to allow a client to start the auth process
    var callbackPermitAuth: (ClientToken) -> Bool = { _ in true }
    /// Server callback to notify a previously authing client has failed
    var callbackAuthFailed: (ClientToken) -> Void = { _ in }
    /// Server callback to notify a client is authenticated and ready to go - return player index
    var callbackAuthSuccess: (ClientToken, SteamID) -> PlayerIndex = { _, _ in 0 }
    ///  Server callback to notify a previously 'authsuccess' client has disconnected
    var callbackDisconnected: (ClientToken) -> Void = { _ in }

    final class Client {
        enum State {
            case pending
            case authInProgress
            case connected
        }
        var state: State
        var steamID: SteamID?
        var lastDataTime: TickSource.TickCount

        init(now: TickSource.TickCount) {
            self.state = .pending
            self.steamID = nil
            self.lastDataTime = now
        }
    }
    private var clients: [ClientToken : Client]
    private func getClient(steamID: SteamID) -> (ClientToken, Client)? {
        clients.first(where: { $0.value.steamID.map { $0 == steamID } ?? false })
    }

    // MARK: Init/Deinit

    init(steam: SteamGameServerAPI, tickSource: TickSource, serverName: String) {
        self.steam = steam
        self.tickSource = tickSource
        self.serverName = serverName

        clients = [:]

        if !FAKE_NET_USE {
            listenSocket = steam.networkingSockets.createListenSocketP2P(localVirtualPort: 0, options: [])
            pollGroup = steam.networkingSockets.createPollGroup()

            steam.onSteamNetConnectionStatusChangedCallback { [weak self] in
                self?.onNetConnectionStatusChanged(msg: $0)
            }
        } else {
            listenSocket = nil
            pollGroup = nil
        }

        steam.onValidateAuthTicketResponse { [weak self] in
            self?.onAuthSessionResponse(msg: $0)
        }
    }

    /// Late initialization for steam ID
    var steamID: SteamID = .nil {
        didSet {
            OutputDebugString("ServerConnection assigned steam ID \(steamID)")
            // Now we know the 'real' server steam ID start listening on it
            if FAKE_NET_USE {
                FakeNet.allocateEndpoint(for: steamID)
                FakeNet.startListening(at: steamID)
            }
        }
    }

    deinit {
        OutputDebugString("ServerConnection deinit")
        if let listenSocket {
            steam.networkingSockets.closeListenSocket(socket: listenSocket)
        }
        if let pollGroup {
            steam.networkingSockets.destroyPollGroup(pollGroup: pollGroup)
        }
        if FAKE_NET_USE && steamID.isValid {
            FakeNet.stopListening(at: steamID)
            FakeNet.freeEndpoint(for: steamID)
        }
    }

    // MARK: Client connect/disconnect

    /// Steam networking state change: spot connects and disconnects
    private func onNetConnectionStatusChanged(msg: SteamNetConnectionStatusChangedCallback) {
        if msg.info.listenSocket != .invalid && msg.oldState == .none && msg.info.state == .connecting {
            let rc = steam.networkingSockets.acceptConnection(conn: msg.conn)
            if rc != .ok {
                OutputDebugString("ServerConnection AcceptConnection failed: \(rc)")
                steam.networkingSockets.closeConnection(peer: msg.conn, reason: 0 /*XXX*/, debug: "Failed to accept connection", enableLinger: false)
                return
            }
            steam.networkingSockets.setConnectionPollGroup(conn: msg.conn, pollGroup: pollGroup!)

            connect(client: .netConnection(msg.conn))
        } else if (msg.oldState == .connecting || msg.oldState == .connected) &&
                    msg.info.state == .closedByPeer {
            disconnect(client: .netConnection(msg.conn))
        }
    }

    /// Handle connection from a new client
    private func connect(client token: ClientToken) {
        precondition(clients[token] == nil, "Duplicate connection")
        clients[token] = Client(now: tickSource.currentTickCount)
        OutputDebugString("ServerConnection new client connection \(token)")

        // Send them the server info as a reliable message
        let msg = MsgServerSendInfo(steamID: steamID,
                                    isVACSecure: steam.gameServer.secure(),
                                    serverName: serverName)
        send(msg: msg, to: token, sendFlags: .reliable)
    }

    /// Handle disconnecting a client
    private func disconnect(client token: ClientToken) {
        guard let client = clients.removeValue(forKey: token) else {
            OutputDebugString("ServerConnection odd disconnect for unknown \(token)")
            return
        }
        OutputDebugString("ServerConnection disconnect \(token) from \(client.state)")

        switch client.state {
        case .pending:
            // Have not told server about this client
            break
        case .authInProgress:
            // Have told the server we're working on this one, and waiting for auth from steam
            callbackAuthFailed(token)
        case .connected:
            // Server knows all about this one
            callbackDisconnected(token)
        }

        if case let .netConnection(conn) = token {
            steam.networkingSockets.closeConnection(peer: conn, reason: 0 /*ClientDisconnect*/, debug: "", enableLinger: false)
        }

        if let steamID = client.steamID {
            OutputDebugString("ServerConnection disconnect EndAuthSession")
            steam.gameServer.endAuthSession(steamID: steamID)
        }
    }

    func testClientLivenessTimeouts() {
        clients.forEach { kv in
            if tickSource.currentTickCount.isLongerThan(Misc.SERVER_TIMEOUT_MILLISECONDS, since: kv.value.lastDataTime) {
                OutputDebugString("ServerConnection client timeout \(kv.key)")
                disconnect(client: kv.key) /* XXX reason k_EDRClientKicked*/
            }
        }
    }

    // MARK: Authentication

    /// Received a beginauthentication message from someone
    func onBeginAuthentication(message: SteamMsgProtocol) {
        OutputDebugString("ServerConnection ClientBeginAuth \(message.token)")

        guard message.size == MsgClientBeginAuthentication.networkSize else {
            OutputDebugString("ServerConnection bad length for beginauth \(message.size)")
            return
        }
        let beginAuthMsg = MsgClientBeginAuthentication(data: message.data)

        guard let client = clients[message.token] else {
            preconditionFailure("Got message from client that is not connected \(message.token)")
        }

        // First, check this isn't a duplicate and we already have a user logged on from the same steamid
        guard client.state == .pending else {
            OutputDebugString("ServerConnection unexpected auth message for existing client, ignoring")
            return
        }

        // We are full (or will be if the pending players auth), deny new login
        guard callbackPermitAuth(message.token) else {
            OutputDebugString("ServerConnection client auth rejected (full)")
            disconnect(client: message.token) /* XXX reason */
            return
        }

        // If we get here there is room, add the player as pending auth
        client.state = .authInProgress
        client.steamID = message.sender
        OutputDebugString("ServerConnection pending -> authInProgress \(message.sender)")

        // Authenticate the user with the Steam back-end servers
        let res = steam.gameServer.beginAuthSession(authTicket: beginAuthMsg.token, steamID: message.sender)
        if res != .ok {
            OutputDebugString("ServerConnection BeginAuthSession failed \(res) \(message.sender)")
            disconnect(client: message.token) /* XXX reason */
        }
    }

    /// Callback after `beginAuthSession` to give the steam server's pass/fail.  Also called asynchronously if the
    /// client/something changes to make a previously validated token invalid.
    ///
    /// Tells us Steam3 (VAC and newer license checking) has accepted the user connection
    private func onAuthSessionResponse(msg: ValidateAuthTicketResponse) {
        guard let (token, client) = getClient(steamID: msg.steamID) else {
            OutputDebugString("ServerConnection AuthSessionRsp unknown \(msg.steamID)")
            return
        }

        guard msg.authSessionResponse == .ok else {
            // Looks like we shouldn't let this user play, kick them
            OutputDebugString( "ServerConnection AuthSessionFail(\(msg.authSessionResponse)) for \(token)")
            // Send a deny for the client
            send(msg: MsgServerFailAuthentication(), to: token, sendFlags: .reliable)
            disconnect(client: token)
            return
        }

        // This is the final approval, and means we should let the client play
        OutputDebugString("ServerConnection AuthSessionSuccess for \(token)")
        guard client.state == .authInProgress else {
            OutputDebugString("ServerConnection already authed this client, nothing to do")
            return
        }

        let position = callbackAuthSuccess(token, client.steamID!)
        OutputDebugString("ServerConnection authInProgress -> connected \(token)")
        client.state = .connected

        send(msg: MsgServerPassAuthentication(playerPosition: UInt32(position)), to: token, sendFlags: .reliable)
    }

    // MARK: Networking send/receive

    /// Send a message to a client
    @discardableResult
    func send(msg: any SpaceWarMsg, to client: ClientToken, sendFlags: SteamNetworkingSendFlags) -> Bool {
        msg.inWireFormat() { ptr, size in
            switch client {
            case .steamID(let steamID):
                FakeNet.send(from: self.steamID, to: steamID, data: ptr, size: size)
            case .netConnection(let conn):
                let res = steam.networkingSockets.sendMessageToConnection(conn: conn, data: ptr, dataSize: size, sendFlags: sendFlags)
                if res.rc != .ok {
                    OutputDebugString("Server Connection SendMsg failed: \(res.rc)")
                }
            }
            return true
        }
    }

    /// Send a message to all connected clients
    func sendToAll(msg: any SpaceWarMsg, sendFlags: SteamNetworkingSendFlags) {
        clients.forEach { kv in
            guard kv.value.state == .connected else {
                return
            }
            send(msg: msg, to: kv.key, sendFlags: sendFlags)
        }
    }

    /// Send a message to each connected client *except* one (who presumably just sent the message to us for propagation)
    func sendToAll(msg: any SpaceWarMsg, except: ClientToken, sendFlags: SteamNetworkingSendFlags) {
        clients.forEach { kv in
            guard kv.key != except, kv.value.state == .connected else {
                return
            }
            send(msg: msg, to: kv.key, sendFlags: sendFlags)
        }
    }

    /// Receive messages - called on frame loop
    func receiveMessages(handler: (ClientToken, Msg, Int, UnsafeMutableRawPointer) -> Void) {
        // First deal with FAKE_NET connection requests
        if FAKE_NET_USE && steamID.isValid {
            while let connectMsg = FakeNet.acceptConnection(at: steamID) {
                if connectMsg.connectNotDisconnect {
                    connect(client: .steamID(connectMsg.from))
                } else {
                    disconnect(client: .steamID(connectMsg.from))
                }
            }
        }

        // Poll all connected sockets for messages
        var messages: [SteamMsgProtocol] = []
        if !FAKE_NET_USE {
            let rc = steam.networkingSockets.receiveMessagesOnPollGroup(pollGroup: pollGroup!, maxMessages: 128)
            messages = rc.messages
        } else if steamID.isValid {
            let rc = steam.networkingSockets.receiveMessagesOnConnection(conn: nil, steamID: steamID, maxMessages: 128)
            messages = rc.messages
        }

        messages.forEach { message in
            defer { message.release() }

            guard message.size > MemoryLayout<UInt32>.size else {
                OutputDebugString("ServerConnection got garbage on client socket, too short")
                return
            }

            guard let msg = Unpack.msgDword(message.data) else {
                OutputDebugString("ServerConnection got garbage on client socket, bad msg cookie")
                return
            }

            clients[message.token]?.lastDataTime = tickSource.currentTickCount

            if msg == .clientBeginAuthentication {
                onBeginAuthentication(message: message)
            } else {
                handler(message.token, msg, message.size, message.data)
            }
        }
    }
}
