//
//  SpaceWarServer.swift
//  SpaceWar
//

import MetalEngine
import Steamworks
import simd

typealias PlayerIndex = Int /* 0...3 */

final class SpaceWarServer {
    let engine: Engine2D
    let controller: Controller
    let steam: SteamGameServerAPI

    /// Network connection component
    let serverConnection: SpaceWarServerConnection

    /// Published state
    private(set) var isConnectedToSteam: Bool

    var steamID: SteamID {
        steam.gameServer.getSteamID()
    }

    /// Internal state -- watch out, this is serialized to clients over the network
    enum State: UInt32 {
      case waitingForPlayers
      case active
      case draw
      case winner
    }
    private var state: MonitoredState<State>

    // Game state

    /// Number of players on the way to being connected
    private var pendingPlayerCount: Int

    /// Active players
    final class Player {
        var ship: Ship
        var score: UInt32
        let client: ClientToken
        let steamID: SteamID
        let index: PlayerIndex
        init(ship: Ship, client: ClientToken, steamID: SteamID, index: PlayerIndex) {
            self.ship = ship
            self.score = 0
            self.client = client
            self.steamID = steamID
            self.index = index
        }
    }
    private var players: [Player?] // historical reasons indexed by PlayerIndex
    private var activePlayers: some Collection<Player> {
        players.compactMap { $0 }
    }
    private var activePlayerCount: Int {
        activePlayers.count
    }
    private func clientToIndex(_ client: ClientToken) -> PlayerIndex? {
        players.firstIndex() { $0.map { $0.client == client } ?? false }
    }
    private func clientToPlayer(_ client: ClientToken) -> Player? {
        clientToIndex(client).flatMap { players[$0] }
    }
    private var ships: some Collection<Ship?> {
        players.map { $0.map(\.ship) }
    }
    /// Scores (number of rounds won)
    private var playerScores: [Int]
    /// Who won the most recent game
    private var playerWhoWonGame: PlayerIndex

    /// Server tick scheduler
    private var serverTick: Debounced

    /// Sun object (for collisions?)
    private var sun: Sun

    // MARK: Initialization

    init(engine: Engine2D, controller: Controller, name: String) {
        self.engine = engine
        self.controller = controller
        self.state = .init(tickSource: engine, initial: .waitingForPlayers, name: "Server")

        // Initialize the SteamGameServer interface, we tell it some info about us, and we request support
        // for both Authentication (making sure users own games) and secure mode, VAC running in our game
        // and kicking users who are VAC banned

        // !FIXME! We need a way to pass the dedicated server flag here!

        guard let steam = SteamGameServerAPI(port: Misc.SPACEWAR_SERVER_PORT, queryPort: Misc.SPACEWAR_MASTER_SERVER_UPDATER_PORT, serverMode: .authenticationAndSecure, version: Misc.SPACEWAR_SERVER_VERSION) else {
            preconditionFailure("SteamGameServer init failed")
        }
        self.steam = steam
        steam.useLoggerForSteamworksWarnings()
        steam.networkingUtils.useLoggerForDebug(detailLevel: .everything)

        // Set the "game dir".
        // This is currently required for all games.  However, soon we will be
        // using the AppID for most purposes, and this string will only be needed
        // for mods.  it may not be changed after the server has logged on
        steam.gameServer.setModDir(modDir: "spacewar")

        // These fields are currently required, but will go away soon.
        // See their documentation for more info
        steam.gameServer.setProduct(product: "SteamworksExample")
        steam.gameServer.setGameDescription(gameDescription: "Steamworks Example")

        // We don't support specators in our game.
        // .... but if we did:
        //SteamGameServer()->SetSpectatorPort( ... );
        //SteamGameServer()->SetSpectatorServerName( ... );

        // Initiate Anonymous logon.
        // Coming soon: Logging into authenticated, persistent game server account
        steam.gameServer.logOnAnonymous()

        // Initialize the peer to peer connection process.  This is not required, but we do it
        // because we cannot accept connections until this initialization completes, and so we
        // want to start it as soon as possible.
        if !FAKE_NET_USE {
            steam.networkingUtils.initRelayNetworkAccess()
        }

        // We want to actively update the master server with our presence so players can
        // find us via the steam matchmaking/server browser interfaces
        steam.gameServer.setAdvertiseServerActive(active: true)

        pendingPlayerCount = 0
        players = .init(repeating: nil, count: Misc.MAX_PLAYERS_PER_SERVER)
        playerScores = .init(repeating: 0, count: Misc.MAX_PLAYERS_PER_SERVER)
        playerWhoWonGame = 0

        serverTick = Debounced(debounce: 1000 / Misc.SERVER_UPDATE_SEND_RATE, sample: { true })
        sun = Sun(engine: engine)
        serverConnection = SpaceWarServerConnection(steam: steam, tickSource: engine, serverName: name)
        isConnectedToSteam = false

        initSteamConnectionHooks()
        initConnectionCallbacks()
        OutputDebugString("SpaceWarServer up and waiting for Steam")
    }

    /// Destructor
    deinit {
        OutputDebugString("SpaceWarServer deinit")
        activePlayers.forEach {
            // Tell this client we are exiting
            self.serverConnection.send(msg: MsgServerExiting(), to: $0.client, sendFlags: .unreliable)
            // XXX            self.serverConnection.disconnect(client)
        }

        // Disconnect from the steam servers
        steam.gameServer.logOff()
    }

    private func initSteamConnectionHooks() {
        // Tells us when we have successfully connected to Steam
        steam.onSteamServersConnected { [weak self] msg in
            OutputDebugString("SpaceWarServer connected to Steam successfully")
            if let self {
                self.isConnectedToSteam = true
                self.serverConnection.steamID = self.steam.gameServer.getSteamID()
                // log on is not finished until OnPolicyResponse() is called
            }
        }

        // Tells us when there was a failure to connect to Steam
        steam.onSteamServerConnectFailure { [weak self] _ in
            OutputDebugString("SpaceWarServer failed to connect to Steam")
            self?.isConnectedToSteam = false
        }

        // Tells us when we have been logged out of Steam
        steam.onSteamServersDisconnected { [weak self] _ in
            OutputDebugString("SpaceWarServer got logged out of Steam")
            self?.isConnectedToSteam = false
        }

        // Tells us that Steam has set our security policy (VAC on or off)
        steam.onGSPolicyResponse { [weak self] _ in
            guard let self else { return }
            if self.steam.gameServer.secure() {
                OutputDebugString("SpaceWarServer is VAC Secure!")
            } else {
                OutputDebugString("SpaceWarServer is not VAC Secure!")
            }
        }
    }

    // MARK: State machine

    /// Main frame function, updates the state of the server and broadcast state to clients
    func runFrame() {
        // Run any Steam Game Server API callbacks
        steam.runCallbacks()

        // Update our server details
        sendUpdatedServerDetailsToSteam()

        // Timeout stale player connections
        serverConnection.testClientLivenessTimeouts()

        switch state.state {
        case .waitingForPlayers:
            // Initial server state: we never come back to here after starting, just loop between
            // 'active' and 'draw'.
            //
            // Wait a few seconds (so everyone can join if a lobby just started this server)
            if engine.currentTickCount.isLongerThan(Misc.MILLISECONDS_BETWEEN_ROUNDS, since: state.transitionTime) {
                // Just keep waiting until at least one ship is active
                if activePlayerCount > 0 {
                    OutputDebugString("SpaceWarServer wait and players present, starting first round")
                    state.set(.active)
                }
            }

        case .active:
            // Update all the entities...
            sun.runFrame()
            activePlayers.forEach { $0.ship.runFrame() }
            // Check for collisions which could lead to a winner this round
            checkForCollisions()

        case .draw, .winner:
            // Update all the entities...
            sun.runFrame()
            activePlayers.forEach { $0.ship.runFrame() }
            // NOTE: no collision detection, because the round is really over, objects are now invulnerable
            // After 5 seconds start the next round
            if engine.currentTickCount.isLongerThan(Misc.MILLISECONDS_BETWEEN_ROUNDS, since: state.transitionTime) {
                resetPlayerShips()
                OutputDebugString("SpaceWarServer round-wait over, starting next round")
                state.set(.active)
            }
        }

        // Send client updates (will internal limit itself to the tick rate desired)
        sendUpdateDataToAllClients()
    }

    // MARK: Game and player database

    private func initConnectionCallbacks() {
        serverConnection.callbackPermitAuth = { [unowned self] in self.connectPermitAuth(client: $0) }
        serverConnection.callbackAuthSuccess = { [unowned self] in self.connectAuthSuccess(client: $0, steamID: $1) }
        serverConnection.callbackAuthFailed = { [unowned self] in self.connectAuthFailed(client: $0) }
        serverConnection.callbackDisconnected = { [unowned self] in self.connectDisconnected(client: $0) }
    }

    /// New client attempting to connect: do we have space?
    func connectPermitAuth(client: ClientToken) -> Bool {
        let pendingOrActiveCount = pendingPlayerCount + activePlayerCount
        // We are full (or will be if the pending players auth), deny new login
        guard pendingOrActiveCount < Misc.MAX_PLAYERS_PER_SERVER else {
            OutputDebugString("SpaceWarServer full, rejecting new client \(client)")
            return false
        }
        pendingPlayerCount += 1
        OutputDebugString("SpaceWarServer pendingPlayerCount=\(pendingPlayerCount)")
        return true
    }

    /// Auth failed, client is no longer pending
    func connectAuthFailed(client: ClientToken) -> Void {
        precondition(pendingPlayerCount > 0, "No pending players after auth failure")
        pendingPlayerCount -= 1
    }

    /// Previously pending client has successfully authenticated and is ready to join
    /// Return the newly assigned player index.
    func connectAuthSuccess(client: ClientToken, steamID: SteamID) -> PlayerIndex {
        precondition(pendingPlayerCount > 0, "No pending players after auth success")
        guard let playerIndex = players.firstIndex(where: { $0 == nil }) else {
            preconditionFailure("No space for new player")
        }

        // Add a new ship, make it dead immediately
        let ship = addPlayerShip(shipPosition: playerIndex)
        ship.isDisabled = true
        players[playerIndex] = Player(ship: ship, client: client, steamID: steamID, index: playerIndex)
        OutputDebugString("SpaceWarServer added new player")

        // If we just got the second player, immediately reset round as a draw.  This will prevent
        // the existing player getting a win, and it will cause a new round to start right off
        // so that the one player can't just float around not letting the new one get into the game.
        if activePlayerCount == 2 && state.state != .waitingForPlayers {
            state.set(.draw)
        }

        return playerIndex
    }

    /// Server callback to notify a previously 'authsuccess' client has disconnected
    func connectDisconnected(client: ClientToken) {
        guard let playerIndex = clientToIndex(client) else {
            preconditionFailure("Disconnecting client not known \(client)")
        }

        removePlayerFromServer(shipPosition: playerIndex)
    }

    /// Adds/initializes a new player ship at the given position
    private func addPlayerShip(shipPosition: PlayerIndex) -> Ship {
        precondition(shipPosition < Misc.MAX_PLAYERS_PER_SERVER)

        let size = engine.viewportSize
        let offset = size * 0.12

        let angle = atan2(size.y, size.x) + .pi/2.0
        let pos: SIMD2<Float>
        let rotation: Float

        switch shipPosition {
        case 0:
            pos = offset
            rotation = angle
        case 1:
            pos = .init(size.x - offset.x, offset.y)
            rotation = -1.0 * angle
        case 2:
            pos = .init(size.x, size.y - offset.y)
            rotation = .pi - angle
        case 3:
            pos = size - offset
            rotation = -1.0 * (.pi - angle)
        default:
            preconditionFailure()
        }
        let ship = Ship(engine: engine, controller: controller, isServerInstance: true, pos: pos, color: Misc.PlayerColors[shipPosition])
        ship.setInitialRotation(rotation)
        return ship
    }

    /// Removes a player at the given position
    private func removePlayerFromServer(shipPosition: PlayerIndex) {
        precondition(shipPosition < Misc.MAX_PLAYERS_PER_SERVER)
        guard players[shipPosition] != nil else {
            preconditionFailure("Removing ship position with no player (\(shipPosition)")
        }

        OutputDebugString("SpaceWarServer removing ship position \(shipPosition)")
        players[shipPosition] = nil
    }

    /// Reset player positions (occurs in between rounds as well as at the start of a new game)
    private func resetPlayerShips() {
        // Delete any currently active ships, but immediately recreate
        // (which causes all ship state/position to reset)
        players = players.enumerated().map { (index, player) in
            guard let player else { return nil }
            player.ship = addPlayerShip(shipPosition: index)
            return player
        }
    }

    // MARK: Game Logic

    /// Checks various game objects for collisions and updates state appropriately if they have occurred
    private func checkForCollisions() {
        // Make the ships check their photons for ones that have hit the sun and remove
        // them before we go and check for them hitting the opponent
        ships.forEach { $0?.destroyPhotons(collidingWith: sun) }

        // Array to track who exploded, can't set the ship exploding within the loop below,
        // or it will prevent that ship from colliding with later ships in the sequence
        var explodingShips: Set<PlayerIndex> = []

        // Check each ship for colliding with the sun or another ships photons
        ships.enumerated().forEach { i, ship in
            // If the pointer is invalid skip the ship
            guard let ship else {
                return
            }

            if ship.collides(with: sun) {
                explodingShips.insert(i)
            }

            ships.enumerated().forEach { j, otherShip in
                guard let otherShip, j != i else {
                    // Don't check against your own photons, or NULL pointers!
                    return
                }

                if ship.collides(with: otherShip) {
                    explodingShips.insert(i)
                }
                if otherShip.checkForPhotons(collidingWith: ship) {
                    if ship.shieldStrength > 200 {
                        // Shield protects from the hit
                        ship.shieldStrength = 0
                        otherShip.destroyPhotons(collidingWith: ship)
                    } else {
                        explodingShips.insert(i)
                    }
                }
            }
        }
        explodingShips.forEach {
            players[$0]!.ship.setExploding(true)
        }
        
        if let gameState = lookForWinner() {
            state.set(gameState)
        }
    }

    func lookForWinner() -> State? {
        let couldBeWinners = activePlayers.filter { !$0.ship.isDisabled }
        let exploded = couldBeWinners.filter { $0.ship.isExploding }

        if exploded.count == couldBeWinners.count {
            OutputDebugString("SpaceWarServer All exploded, declaring draw")
            return .draw
        }

        guard couldBeWinners.count > 1, // Can't be a winner on your own
              exploded.count + 1 < couldBeWinners.count else { // still players
            return nil
        }

        let winner = activePlayers.first(where: { !$0.ship.isExploding })!
        OutputDebugString("SpaceWarServer One left, declaring winner \(winner.index)")
        playerWhoWonGame = winner.index
        playerScores[playerWhoWonGame] += 1
        OutputDebugString("SpaceWarServer New scores: \(playerScores)")
        return .winner
    }

    // MARK: Game state send/receive

    /// Purpose: Receives update data from a client
    func onReceiveClientUpdateData(client: ClientToken, msg: MsgClientSendLocalUpdate) {
        guard let player = players[msg.shipPosition],
              player.client == client else {
            OutputDebugString("Confused by client update, out of sync - \(client)")
            return
        }
        player.ship.onReceiveClientUpdate(data: msg.update)
    }

    /// Send world update to all clients
    func sendUpdateDataToAllClients() {
        // Limit the rate at which we update, even if our internal frame rate is higher
        guard serverTick.test(now: engine.gameTickCount) else {
            return
        }

        var msg = MsgServerUpdateWorld(gameState: state.state, playerWhoWonGame: playerWhoWonGame)

        players.enumerated()
            .filter { $0.1 != nil}
            .forEach { index, player in
                msg.playersActive[index] = true
                msg.playerScores[index] = player!.score
                msg.playerSteamIDs[index] = player!.steamID
                msg.shipData[index] = player!.ship.buildServerUpdate()
            }

        serverConnection.sendToAll(msg: msg, sendFlags: .unreliable)
    }

    // MARK: Utilities

    /// Receives incoming network data and dispatches it
    func receiveNetworkData() {
        serverConnection.receiveMessages() { client, msg, size, data in
            switch msg {
            case .clientSendLocalUpdate:
                if size != MsgClientSendLocalUpdate.networkSize {
                    OutputDebugString("Bad client update msg, too short \(size)")
                    return
                }
                onReceiveClientUpdateData(client: client, msg: MsgClientSendLocalUpdate(data: data))

            case .voiceChatData:
                // Received voice chat messages, broadcast to all other players
                var msg = MsgVoiceChatData(data: data)
                msg.steamID = clientToPlayer(client)!.steamID // Make sure sender steam ID is set.
                serverConnection.sendToAll(msg: msg, except: client, sendFlags: .reliable)

            case .P2PSendingTicket:
                // Received a P2P auth ticket, forward it to the intended recipient
                var msg = MsgP2PSendingTicket(data: data)
                let toSteamID = msg.steamID
                guard let dstPlayer = activePlayers.first(where: { $0.steamID == toSteamID }) else {
                    OutputDebugString("msgP2PSendingTicket received with no valid target to send to.")
                    break
                }
                // Mutate the message, replacing the destination SteamID with the sender's SteamID
                msg.steamID = clientToPlayer(client)!.steamID
                serverConnection.send(msg: msg, to: dstPlayer.client, sendFlags: .reliable)

            default:
                OutputDebugString("SpaceWarServer Unexpected message \(msg)")
            }
        }
    }

    /// Exernal API to kick a given player off the server - p2p auth failure
    func kickPlayerOffServer(steamID: SteamID) {
        guard let player = activePlayers.first(where: { $0.steamID == steamID }) else {
            // If there is no ship, skip
            OutputDebugString("SpaceWarServer KickPlayerOffServer Don't know player \(steamID)")
            return
        }

        OutputDebugString("SpaceWarServer Kicking player \(steamID)")
        serverConnection.send(msg: MsgServerFailAuthentication(), to: player.client, sendFlags: .reliable)
        // XXX serverConnection.kickPlayer(client: player.client)
    }

    /// Called every frame to tell Steam about the game & players
    private func sendUpdatedServerDetailsToSteam() {
        // Set state variables, relevant to any master server updates or client pings

        // These server state variables may be changed at any time.  Note that there is no lnoger a mechanism
        // to send the player count.  The player count is maintained by steam and you should use the player
        // creation/authentication functions to maintain your player count.
        steam.gameServer.setMaxPlayerCount(playersMax: Misc.MAX_PLAYERS_PER_SERVER)
        steam.gameServer.setPasswordProtected(passwordProtected: false)
        steam.gameServer.setServerName(serverName: serverConnection.serverName)
        steam.gameServer.setBotPlayerCount(botplayers: 0) // optional, defaults to zero
        steam.gameServer.setMapName(mapName: "MilkyWay")

        // Update all the players names/scores
//        activePlayers.forEach { player in
//            steam.gameServer.updateUserData(user: player.steamID, playerName: player.ship.playerName, score: player.score)
// XXX  }
        // game type is a special string you can use for your game to differentiate different game play
        // types occurring on the same maps
        // When users search for this parameter they do a sub-string search of this string
        // (i.e if you report "abc" and a client requests "ab" they return your server)
        //SteamGameServer()->SetGameType( "dm" );

        // update any rule values we publish
        //SteamMasterServerUpdater()->SetKeyValue( "rule1_setting", "value" );
        //SteamMasterServerUpdater()->SetKeyValue( "rule2_setting", "value2" );
    }
}
