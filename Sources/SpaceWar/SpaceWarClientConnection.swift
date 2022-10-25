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

    /// State machine, for debug and some use
    enum State {
        /// Initial state, not connected to a server
        case notConnected
        /// Trying to connect to a server socket
        case connectingP2P
        /// We've established communication with the server, but it hasn't authed us yet
        case connectedPendingAuthentication
        /// Final phase, server has authed us, we are actually able to play on it
        case connectedAndAuthenticated
    }
    /// Hiding this for now, with some predicates...
    private var state: State

    /// Are we connected to a server?
    var isConnected: Bool {
        state == .connectedPendingAuthentication || state == .connectedAndAuthenticated
    }

    /// Time we started the current connection
    private var connectionStartTime: TickSource.TickCount

    /// We need steam for various APIs and a timebase for timeouts
    init(steam: SteamAPI, tickSource: TickSource) {
        self.steam = steam
        self.tickSource = tickSource
        self.state = .notConnected
        self.connectionStartTime = 0

        steam.onSteamNetConnectionStatusChangedCallback { [weak self] in
            self?.onSteamNetConnectionStatusChanged(msg: $0)
        }
    }

    /// The error reason from the most recent connection failure
    private(set) var connectionError: String?
    /// The net connection for the current connection/attempted connection, or nil if none
    private(set) var netConnection: HSteamNetConnection?
    /// The Steam ID of the game server, or nil if not connected/don't know yet
    private(set) var serverSteamID: SteamID?
    /// Server IP details, used for rich presence
    private var serverIP: Int?
    /// Server IP details, used for rich presence
    private var serverPort: UInt16?
    /// Authentication ticket
    private var authTicket: HAuthTicket?

    /// Connect to a server directly via a Steam ID
    func connect(steamID: SteamID) {
        precondition(state == .notConnected, "Server connection already busy: \(state)")
        OutputDebugString("ClientConnection \(state) -> connectingP2P")
        state = .connectingP2P
        serverSteamID = steamID
        
        if !FAKE_NET_USE {
            let identity = SteamNetworkingIdentity(steamID)
            netConnection = steam.networkingSockets.connectP2P(identityRemote: identity, remoteVirtualPort: 0, options: [])
        } else {
            FakeNet.connect(to: steamID, from: steam.user.getSteamID())
        }

        connectionError = nil
        connectionStartTime = tickSource.currentTickCount
    }

    /// Connect to a server via IP and port - alternate flow, have to look up the SteamID and go back to the steam ID
    func connect(ip: Int, port: UInt16) {
        preconditionFailure("Not implemented") /* XXX ip-connect */
    }

    /// Has there been a connection timeout?
    ///
    /// Return `true` means that we have timed out, all resources have been torn down, we're ready for a
    /// new connection attempt, `connectionError` is set.  Return `false` means keep waiting.
    func testConnectionTimeout() -> Bool {
        precondition(!isConnected, "Server connection is connected \(state), not timing anything")

        guard tickSource.currentTickCount.isLongerThan(Misc.MILLISECONDS_CONNECTION_TIMEOUT,
                                                       since: connectionStartTime) else {
            return false
        }
        OutputDebugString("ClientConnection timeout, disconnecting")
        disconnect(reason: "Timed out connecting to game server")
        return true
    }

    /// Tear down the current connection/attempt.
    ///
    /// Safe to call in any state.  Does not set `connectionError`.
    func disconnect(reason: String) {
        if connectionError == nil {
            connectionError = reason
        }

        /* if state == .queryingServerIP {
             cancel it
           }
        */
        OutputDebugString("ClientConnection disconnecting from \(state)")

        if let authTicket {
            steam.user.cancelAuthTicket(authTicket: authTicket)
            self.authTicket = nil
        }

        state = .notConnected
        if let netConnection {
            steam.networkingSockets.closeConnection(peer: netConnection,
                                                    reason: DisconnectReason.clientDisconnect,
                                                    debug: "", enableLinger: false)
            self.netConnection = nil
        }
        serverSteamID = nil

        serverIP = nil
        serverPort = nil
    }

    /// Callback on our socket connection changing state.  Spot failures and disconnect.
    /// The Client will pick up the connectionError message and follow us.
    func onSteamNetConnectionStatusChanged(msg: SteamNetConnectionStatusChangedCallback) {
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

    func receive(msg: Msg, size: Int, data: UnsafeMutableRawPointer) -> Bool {
        switch msg {
        case .serverSendInfo:
            if size != MsgServerSendInfo.networkSize {
                OutputDebugString("Bad server info msg: \(size)")
                break
            }
            receive(serverInfo: .init(data: data))
        default:
            return false
        }
        return true
    }

    /// Receive basic server info from the server after we initiate a connection, start authentication
    func receive(serverInfo: MsgServerSendInfo) {
        precondition(state == .connectingP2P, "ClientConnection not expecting ServerSendInfo")
        OutputDebugString("ClientConnection \(state) -> connectedPendingAuthentication")
        state = .connectedPendingAuthentication

        serverSteamID = serverInfo.steamIDServer
        //    m_pQuitMenu->SetHeading( pchServerName ); XXX fuck!

        let rc = steam.networkingSockets.getConnectionInfo(conn: netConnection!)
        serverIP = rc.info.addrRemote.ipv4
        serverPort = rc.info.addrRemote.port

        // set how to connect to the game server, using the Rich Presence API
        // this lets our friends connect to this game via their friends list
        refreshRichPresenceConnection()

        let authStatus = steam.user.getAuthSessionTicket()
        if authStatus.ticketSize < 1 {
            OutputDebugString("Warning: Looks like GetAuthSessionTicket didn't give us a good ticket")
        }
        authTicket = authStatus.rc
        let msg = MsgClientBeginAuthentication(token: authStatus.ticket)

        Steamworks_TestSecret()

        //    BSendServerData( &msg, sizeof(msg), k_nSteamNetworkingSend_Reliable );
    }

    func refreshRichPresenceConnection() {
        if let serverIP, let serverPort, state == .connectedAndAuthenticated {
            steam.friends.setRichPresence(connectedTo: .server(serverIP, serverPort))
        }
    }
}
