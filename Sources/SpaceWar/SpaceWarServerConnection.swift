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
    let listenSocket: HSteamListenSocket?
    let pollGroup: HSteamNetPollGroup?

    /// Server callback to check it's OK to allow a client to start the auth process
    var callbackPermitAuth: (ClientToken) -> Bool = { _ in true }
    /// Server callback to notify a previously authing client has failed
    var callbackAuthFailed: (ClientToken) -> Void = { _ in }
    /// Server callback to notify a client is authenticated and ready to go!
    var callbackAuthSuccess: (ClientToken, SteamID) -> Void = { _, _ in }
    ///  Server callback to notify a previously 'authsuccess' client has disconnected
    var callbackDisconnected: (ClientToken) -> Void = { _ in }

    struct Client {
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

    init(steam: SteamGameServerAPI, tickSource: TickSource) {
        self.steam = steam
        self.tickSource = tickSource

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
    func onNetConnectionStatusChanged(msg: SteamNetConnectionStatusChangedCallback) {
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
                                    serverName: "WHAT IS MY NAME" /* XXX*/)
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
            steam.gameServer.endAuthSession(steamID: steamID)
        }
    }

    // MARK: Inbound messages

    func receive(msg: Msg, message: SteamMsgProtocol) -> Bool {
        switch msg {
        case .clientBeginAuthentication:
            OutputDebugString("ServerConnection ClientBeginAuth \(message.token)")
            return true // handled it
        default:
            return false // keep looking
        }
    }

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

        func handle(message: SteamMsgProtocol) {
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

            if receive(msg: msg, message: message) {
                // we handled it, don't pass to client
                return
            }

            handler(message.token, msg, message.size, message.data)
        }

        // Poll all connected sockets for messages

        if !FAKE_NET_USE {
            let rc = steam.networkingSockets.receiveMessagesOnPollGroup(pollGroup: pollGroup!, maxMessages: 128)
            rc.messages.forEach { handle(message: $0) }
        } else if steamID.isValid {
            let rc = steam.networkingSockets.receiveMessagesOnConnection(conn: nil, steamID: steamID, maxMessages: 128)
            rc.messages.forEach { handle(message:$0) }
        }
    }

    // MARK: Utilities

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

    /// Send a message to each connected client *except* one (who presumably just sent the message to us for propagation)
    func sendToAll(msg: any SpaceWarMsg, except: ClientToken, sendFlags: SteamNetworkingSendFlags) {
        clients.forEach { kv in
            guard kv.key != except, kv.value.state == .connected else {
                return
            }
            send(msg: msg, to: kv.key, sendFlags: sendFlags)
        }
    }
}
