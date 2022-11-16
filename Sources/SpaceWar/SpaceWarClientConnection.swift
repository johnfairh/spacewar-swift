//
//  SpaceWarClientConnection.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

/// Stuff dealing with establishing the network connection from a client to a server.
///
/// So this does:
/// 1) Figure out the Steam ID of the server.  This may involve a matchmaking query.
/// 2) Attempt to connect to the server by SteamID
/// 3) If the connection fails or times out (polled by Client, not timed here) then report it
/// 4) Publish the NetConnection for inbound messages and other purposes
/// 5) Handle a 'ServerAnnounce' message by beginning an authentication session
/// 6) Handle a 'AuthSuccess' message by completing the connection
/// 7) Handle a 'AuthFailure' message by failing the connection
/// 8) Provide APIs for cleanly tearing down the NetConnection and Auth session
///
/// The normal flow is after step (6) the server sends a 'world update' message which
/// is not our concern - we stay in this terminal state until torn down.
///
/// The server clean-exit message is handled by Client, not us - Client will call our
/// disconnect to tidy up.
///
/// If the connection gets borked or the server hangs after we're done then Client will
/// notice, its watchdog at the top of `runFrame()` will trigger.
///
/// Factored out of SpaceWarClient to save my sanity.
final class SpaceWarClientConnection {
    let steam: SteamAPI
    let tickSource: TickSource
    let mySteamID: SteamID

    /// State machine, for debug and some use
    enum State {
        /// Initial state, not connected to a server
        case notConnected
        /// Trying to connect to a server socket
        case connectingP2P
        /// Querying an IP for a steam address
        case pingingServer
        /// We've established communication with the server, but it hasn't authed us yet
        case connectedPendingAuthentication
        /// Final phase, server has authed us, we are actually able to play on it
        case connectedAndAuthenticated
    }
    /// Hiding this for now, with some predicates...
    private var state: State

    /// Are we connected to a server and ready for game stuff
    var isFullyConnected: Bool {
        state == .connectedAndAuthenticated
    }

    /// Can we receive messages?
    var canReceiveMessages: Bool {
        state != .notConnected && state != .pingingServer
    }

    /// Time we started the current connection
    private var connectionStartTime: TickSource.TickCount
    /// Time we last heard from the server
    private var lastNetworkDataReceivedTime: TickSource.TickCount

    /// We need steam for various APIs and a timebase for timeouts
    init(steam: SteamAPI, tickSource: TickSource) {
        self.steam = steam
        self.tickSource = tickSource
        self.mySteamID = steam.user.getSteamID()
        self.state = .notConnected
        self.connectionStartTime = 0
        self.lastNetworkDataReceivedTime = 0

        steam.onSteamNetConnectionStatusChangedCallback { [weak self] in
            self?.onSteamNetConnectionStatusChanged(msg: $0)
        }
    }

    /// Server ping query
    private var serverPing: ServerPing?
    /// The error reason from the most recent connection failure
    private(set) var connectionError: String?
    /// The net connection for the current connection/attempted connection, or nil if none
    private(set) var netConnection: HSteamNetConnection?
    /// The Steam ID of the game server, or nil if not connected/don't know yet
    private(set) var serverSteamID: SteamID?
    /// The name of the server, if known
    private(set) var serverName: String?
    /// Server IP details, used for rich presence
    private var serverIP: Int?
    /// Server IP details, used for rich presence
    private var serverPort: UInt16?
    /// Authentication ticket
    private var authTicket: HAuthTicket?

    // MARK: Connect/Disconnect APIs

    /// Connect to a server directly via a Steam ID
    func connect(steamID: SteamID) {
        precondition(state == .notConnected || state == .pingingServer, "Server connection already busy: \(state)")
        OutputDebugString("ClientConnection \(state) -> connectingP2P")
        state = .connectingP2P
        serverSteamID = steamID
        
        if !FAKE_NET_USE {
            let identity = SteamNetworkingIdentity(steamID)
            netConnection = steam.networkingSockets.connectP2P(identityRemote: identity, remoteVirtualPort: 0, options: [])
        } else {
            FakeNet.allocateEndpoint(for: mySteamID)
            FakeNet.connect(client: mySteamID, server: steamID)
        }

        serverPing = nil
        connectionError = nil
        connectionStartTime = tickSource.currentTickCount
    }

    /// Connect to a server via IP and port - alternate flow, have to look up the SteamID and go back to the steam ID
    func connect(ip: Int, port: UInt16) {
        precondition(state == .notConnected, "Server connection already busy: \(state)")
        OutputDebugString("ClientConnection \(state) -> pingingServer")

        serverIP = ip
        serverPort = port
        connectionError = nil
        connectionStartTime = tickSource.currentTickCount

        serverPing = ServerPing(steam: steam, connection: self)
        serverPing?.ping(ip: ip, port: port)
    }

    /// How much time is left before the timeout?
    var secondsLeftToConnect: UInt {
        let elapsed = tickSource.currentTickCount - connectionStartTime
        if elapsed >= Misc.MILLISECONDS_CONNECTION_TIMEOUT {
            return 0
        }
        return (Misc.MILLISECONDS_CONNECTION_TIMEOUT - elapsed) / 1000
    }

    /// Has there been a server message or connection timeout?
    ///
    /// Sets `connectionError` as a side-effect.  Can be called in any state, ignore if irrelevant.
    func testServerLivenessTimeout() {
        let base: TickSource.TickCount
        let reason: String

        switch state {
        case .notConnected: return
        case .pingingServer, .connectingP2P:
            base = connectionStartTime
            reason = "Timed out connecting to game server"
        case .connectedPendingAuthentication, .connectedAndAuthenticated:
            base = lastNetworkDataReceivedTime
            reason = "Lost connection to game server"
        }

        if tickSource.currentTickCount.isLongerThan(Misc.MILLISECONDS_CONNECTION_TIMEOUT,
                                                    since: base) {
            OutputDebugString("ClientConnection timeout, disconnecting")
            disconnect(reason: reason)
        }
    }

    /// Tear down the current connection/attempt.
    ///
    /// Safe to call in any state.   `reason` is for debug and will occupy connectionError if
    /// it's not set.
    func disconnect(reason: String) {
        if connectionError == nil {
            connectionError = reason
        }

        OutputDebugString("ClientConnection disconnecting from \(state), because \(reason)")

        if let serverPing {
            OutputDebugString("ClientConnection cancelling ping in disconnect")
            serverPing.cancel()
            self.serverPing = nil
        }

        if let authTicket {
            steam.user.cancelAuthTicket(authTicket: authTicket)
            self.authTicket = nil
        }

        state = .notConnected
        if !FAKE_NET_USE {
            if let netConnection {
                steam.networkingSockets.closeConnection(peer: netConnection,
                                                        reason: DisconnectReason.clientDisconnect,
                                                        debug: nil, enableLinger: false)
                self.netConnection = nil
            }
        } else if let serverSteamID {
            FakeNet.disconnect(client: mySteamID, server: serverSteamID)
            FakeNet.freeEndpoint(for: mySteamID)
        }
        serverSteamID = nil

        serverIP = nil
        serverPort = nil
    }

    /// Completely clean up the object's state so it's ready for a new connection
    func terminate() {
        disconnect(reason: "Terminating client session")
        connectionError = nil
    }

    // MARK: Connection Management

    /// Callback on our socket connection changing state.  Spot failures and disconnect.
    /// The Client will pick up the connectionError message and follow us.
    private func onSteamNetConnectionStatusChanged(msg: SteamNetConnectionStatusChangedCallback) {
        guard let netConnection else {
            preconditionFailure("ClientConnection StatusChange but no connection \(state)")
        }
        guard netConnection == msg.conn else {
            preconditionFailure("ClientConnection StatusChange wrong connection \(state)")
        }
        // Full connection info
        let info = msg.info

        // Previous state.  (Current state is in m_info.m_eState)
        let oldState = msg.oldState

        let disconnectReason: String?

        if (oldState == .connecting || oldState == .connected) && info.state == .closedByPeer {
            // Triggered when a server rejects our connection
            switch info.endReason {
            case DisconnectReason.serverReject:
                disconnectReason = "Connection failure: server reports authentication failure"
            case DisconnectReason.serverFull:
                disconnectReason = "Connection failure: server is full"
            default:
                disconnectReason = "Connection failure: server closed connection \(info.endReason)"
                break
            }
        } else if (oldState == .connecting || oldState == .connected) && info.state == .problemDetectedLocally {
            // Triggered if our connection to the server fails
            disconnectReason = "Connection failure: failed to make P2P connection"
        } else {
            disconnectReason = nil
        }
        if let disconnectReason {
            OutputDebugString("ClientConnection StatusChange disconnect: \(disconnectReason)")
            disconnect(reason: disconnectReason)
        }
    }

    // MARK: Message handling

    func receive(msg: Msg, size: Int, data: UnsafeMutableRawPointer) -> Bool {
        switch msg {
        case .serverSendInfo:
            guard size == MsgServerSendInfo.networkSize else {
                OutputDebugString("Bad server info msg: \(size)")
                break
            }
            receive(serverInfo: .init(data: data))

        case .serverFailAuthentication:
            OutputDebugString("ClientConnection: received explicit auth-failure message, disconnecting")
            disconnect(reason: "Server rejected authentication.\nMultiplayer authentication failed.")

        case .serverPassAuthentication:
            guard size == MsgServerPassAuthentication.networkSize else {
                OutputDebugString("Bad server pass-aith msg: \(size)")
                break
            }

            OutputDebugString("ClientConnection \(state) -> connectedAndAuthenticated")
            state = .connectedAndAuthenticated
            // set information so our friends can join the server
            updateRichPresence()

            return false // Allow Client to see the message and read out the game stuff

        case .serverExiting:
            OutputDebugString("ClientConnection: received explicit server-exiting message, disconnecting")
            disconnect(reason: "Server exitted")

        default:
            return false
        }
        return true
    }

    /// Receive basic server info from the server after we initiate a connection, start authentication
    private func receive(serverInfo: MsgServerSendInfo) {
        precondition(state == .connectingP2P, "ClientConnection not expecting ServerSendInfo")
        OutputDebugString("ClientConnection \(state) -> connectedPendingAuthentication \(serverInfo.serverName)")
        state = .connectedPendingAuthentication

        serverSteamID = serverInfo.steamIDServer
        serverName = serverInfo.serverName

        if !FAKE_NET_USE {
            let rc = steam.networkingSockets.getConnectionInfo(conn: netConnection!)
            serverIP = rc.info.addrRemote.ipv4
            serverPort = rc.info.addrRemote.port
        }

        // set how to connect to the game server, using the Rich Presence API
        // this lets our friends connect to this game via their friends list
        updateRichPresence()

        let authStatus = steam.user.getAuthSessionTicket()
        if authStatus.ticketSize < 1 {
            OutputDebugString("Warning: Looks like GetAuthSessionTicket didn't give us a good ticket")
        }
        authTicket = authStatus.rc
        let msg = MsgClientBeginAuthentication(token: authStatus.ticket)

        Steamworks_TestSecret()

        sendServerData(msg: msg, sendFlags: .reliable)
    }

    // MARK: Utilities

    /// Send data to the current server
    @discardableResult
    func sendServerData(msg: any SpaceWarMsg, sendFlags: SteamNetworkingSendFlags) -> Bool {
        msg.inWireFormat() { ptr, size in
            guard let serverSteamID else {
                preconditionFailure("No server steam ID in sendmsg")
                // Might need to return false here, timing windows in disconnect vs. voice/p2pauth
            }
            let (res, _) = steam.networkingSockets.sendMessageToConnection(conn: netConnection, from: mySteamID, to: serverSteamID, data: ptr, dataSize: size, sendFlags: sendFlags)

            switch res {
            case .ok, .ignored:
                break

            case .invalidParam:
                OutputDebugString("Failed sending data to server: Invalid connection handle, or the individual message is too big")
                return false
            case .invalidState:
                OutputDebugString("Failed sending data to server: Connection is in an invalid state")
                return false
            case .noConnection:
                OutputDebugString("Failed sending data to server: Connection has ended")
                return false
            case .limitExceeded:
                OutputDebugString("Failed sending data to server: There was already too much data queued to be sent")
                return false
            default:
                OutputDebugString("SendMessageToConnection returned \(res)")
                return false
            }
            return true
        }
    }

    /// Receive messages from the current server
    func receiveMessages(handler: (Msg, Int, UnsafeMutableRawPointer) -> Void) {
        guard canReceiveMessages else {
            return
        }
        let rc = steam.networkingSockets.receiveMessagesOnConnection(
            conn: netConnection,
            steamID: mySteamID,
            maxMessages: 32)

        rc.messages.forEach { message in
            lastNetworkDataReceivedTime = tickSource.currentTickCount
            defer { message.release() }

            // make sure we're connected [uh... whatever]
            if state == .notConnected {
                OutputDebugString("Ignoring message in weird state \(state)")
                return
            }
            guard message.size > MemoryLayout<UInt32>.size else {
                OutputDebugString("Got garbage on client socket, too short")
                return
            }

            guard let msg = Unpack.msgDword(message.data) else {
                OutputDebugString("Got garbage on client socket, bad msg cookie")
                return
            }

            if receive(msg: msg, size: message.size, data: message.data) {
                // we handled it, don't pass to client
                return
            }

            handler(msg, message.size, message.data)
        }
    }

    /// Update rich presence for our server if we're connected, and the `player_group`
    func updateRichPresence() {
        if let serverIP, let serverPort, state == .connectedAndAuthenticated {
            steam.friends.setRichPresence(connectedTo: .server(serverIP, serverPort))
        } else {
            steam.friends.setRichPresence(connectedTo: .nothing)
        }
        // steam_player_group defines who the user is playing with.  Set it to the steam ID
        // of the server if we are connected, otherwise blank.
        steam.friends.setRichPresence(playerGroup: serverSteamID)
    }
}

// MARK: ServerPing

/// Helper to ping/query a server from an IP address
private final class ServerPing: SteamMatchmakingPingResponse {
    private let steam: SteamAPI
    private weak var connection: SpaceWarClientConnection?
    private var serverQuery: HServerQuery?

    init(steam: SteamAPI, connection: SpaceWarClientConnection) {
        self.steam = steam
        self.connection = connection
    }

    /// Start the ping
    func ping(ip: Int, port: UInt16) {
        serverQuery = steam.matchmakingServers.pingServer(ip: ip, port: port, response: self)
    }

    /// Ping worked - proceed to connecting by steam ID
    func serverResponded(server: GameServerItem) {
        if let connection {
            OutputDebugString("ClientConnection ping response, connecting to Steam ID")
            connection.connect(steamID: server.steamID)
        }
    }

    /// If the ping times out we just forget everything
    func serverFailedToRespond() {
        OutputDebugString("ClientConnection ping failure, waiting for connection timeout")
        connection = nil
    }

    /// Not interested in amy result of the ping
    func cancel() {
        if let serverQuery, connection != nil {
            connection = nil
            steam.matchmakingServers.cancelServerQuery(serverQuery)
            self.serverQuery = nil
        }
    }
}
