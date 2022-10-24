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
    func connect(steamID: SteamID) {}
    func connect(ip: Int, port: UInt16) {}
    func checkConnectionTimeout(now: Engine2D.TickCount) {}
    func disconnect() {}

    private(set) var connectionError: String?

    private(set) var netConnection: HSteamNetConnection?

    private(set) var serverSteamID: SteamID?

    func receive(msgType: FakeMsgType, msg: any FakeMsg) -> Bool { true }
}
