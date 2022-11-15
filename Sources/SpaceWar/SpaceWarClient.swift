//
//  SpaceWar.swift
//  SpaceWar
//

import Steamworks
import MetalEngine
import Foundation

/// Game-related parts of SpaceWarClient.
///
/// SpaceWarMain is in charge of this, initializes it and passes it the baton of
/// running a game, with either a local server or connecting to one.
final class SpaceWarClient {
    private let steam: SteamAPI
    private let engine: Engine2D
    private let controller: Controller
    private let statsAndAchievements: StatsAndAchievements

    /// Main game state
    enum State {
        case idle
        case startServer
        case connecting
        case waitingForPlayers
        case active
        case winner
        case draw
        case quitMenu
        case connectionFailure
    }
    private var state: MonitoredState<State>

    /// Component to manage the server connection
    private let clientConnection: SpaceWarClientConnection

    /// Component to draw screens and text
    private let clientLayout: SpaceWarClientLayout

    /// Component to manage peer-to-peer authentication
    private let p2pAuthedGame: P2PAuthedGame

    /// Voice chat
    private let voiceChat: VoiceChat

    /// A local server we may be running
    private var server: SpaceWarServer?

    /// Pause menu
    private let quitMenu: QuitMenu

    /// Describe the actual game state from our point of view.  Data model is pretty shakey, valid
    /// parts strongly linked to game state...
    struct GameState {
        /// Our ID assigned by the server, used as index into the card-4 arrays
        var playerShipIndex: Int
        /// ID of the player who won the last game, valid only if there is a last-won game
        var playerWhoWonGame: Int
        /// Steam IDs of the players
        var playerSteamIDs: [SteamID]
        /// Current scores,
        var playerScores: [UInt32]
        /// Current ship objects
        var ships: [Ship?]

        init() {
            playerShipIndex = 0
            playerWhoWonGame = 0
            playerSteamIDs = Array(repeating: .nil, count: Misc.MAX_PLAYERS_PER_SERVER)
            playerScores = Array(repeating: 0, count: Misc.MAX_PLAYERS_PER_SERVER)
            ships = Array(repeating: nil, count: Misc.MAX_PLAYERS_PER_SERVER)
        }
    }

    /// The actual game state
    private var gameState: GameState
    let sun: Sun

    init(engine: Engine2D, controller: Controller, steam: SteamAPI, stats: StatsAndAchievements) {
        self.engine = engine
        self.controller = controller
        self.steam = steam
        self.statsAndAchievements = stats
        self.state = .init(tickSource: engine, initial: .idle, name: "Client")
        self.clientConnection = SpaceWarClientConnection(steam: steam, tickSource: engine)
        self.clientLayout = SpaceWarClientLayout(steam: steam, controller: controller, engine: engine)
        self.p2pAuthedGame = P2PAuthedGame(steam: steam, tickSource: engine, connection: clientConnection)
        self.server = nil
        self.gameState = GameState()
        self.sun = Sun(engine: engine)

        self.quitMenu = QuitMenu(engine: engine, controller: controller)
        //    m_nNumWorkshopItems = 0;
        //    for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
        //    {
        //        m_rgpWorkshopItems[i] = NULL;
        //    }
        //    LoadWorkshopItems();

        // Voice chat
        voiceChat = VoiceChat(steam: steam)
    }

    deinit {
        clientConnection.disconnect(reason: "Client object deletion")
        disconnect()
    }

    // MARK: Kick-off entrypoints

    /// Start hosting a new game - `server` can be `nil` in which case it is created in the state machine
    /// This handles 'start server' from the main menu and creating a server via a lobby
    func connectToLocalServer(_ server: SpaceWarServer? = nil) {
        precondition(state.state == .idle, "Must be .idle on connectTo... not \(state)")
        self.server = server
        state.set(.startServer)
    }

    /// Start a new game using a SteamID from a server browser or a lobby
    func connectTo(gameServerSteamID: SteamID) {
        precondition(state.state == .idle || state.state == .startServer, "Must be .idle on connectTo... not \(state)")
        state.set(.connecting)
        clientConnection.connect(steamID: gameServerSteamID)
    }

    /// Start up a new game using an IP address from a CLI-type thing
    func connectTo(serverAddress: Int, port: UInt16) {
        precondition(state.state == .idle, "Must be .idle on connectTo... not \(state)")
        state.set(.connecting)
        clientConnection.connect(ip: serverAddress, port: port)
    }

    // MARK: State machine

    func onStateChanged() {
        switch state.state {
        case .winner, .draw:
            //        // game over.. update the leaderboard
            //        m_pLeaderboards->UpdateLeaderboards(statsAndAchievements)
            //
            // Check if the user is due for an item drop
            SpaceWarLocalInventory.instance.checkForItemDrops()
            setInGameRichPresence()

        case .active:
            // Load Inventory
            SpaceWarLocalInventory.instance.refreshFromServer()
            // start voice chat
            voiceChat.startVoiceChat(connection: clientConnection)
            setInGameRichPresence()

        case .connectionFailure:
            disconnect() // leave game_status rich presence where it was before I guess

        case .quitMenu:
            quitMenu.resetSelection()
            fallthrough

        default:
            steam.friends.setRichPresence(gameStatus: .waitingForMatch)
        }

        steam.friends.setRichPresence(status: state.state.richPresenceStatus)
        clientConnection.updateRichPresence()

        // Let the stats handler check the state (so it can detect wins, losses, etc...)
        statsAndAchievements.onGameStateChanged(state.state)
    }

    /// Cilent tasks to be done on disconnecting from a server - not in a state-change because can
    /// happen at weird times like object deletion.
    func disconnect() {
        p2pAuthedGame.endGame()
        voiceChat.endGame()
        // tell steam china duration control system that we are no longer in a match
        _ = steam.user.setDurationControlOnlineState(newState: .offline)
    }

    /// Frame poll function.
    /// Called by `SpaceWarMain` when it thinks we're in a state of running/starting a game.
    /// Return what we want to do next.
    enum FrameRc {
        case game // stay in game mode
        case mainMenu // quit back to mainMenu
        case quit // quit to desktop
    }

    func runFrame(escapePressed: Bool) -> FrameRc {
        precondition(state.state != .idle, "SpaceWarMain thinks we're busy but we're idle :-(")

        // Check for connection and ping timeout
        clientConnection.testServerLivenessTimeout()

        if state.state != .connectionFailure && clientConnection.connectionError != nil {
            state.set(.connectionFailure)
        }

        // if we just transitioned state, perform on change handlers
        state.onTransition {
            onStateChanged()
        }

        clientConnection.serverName.map { quitMenu.heading = $0 }

        var frameRc = FrameRc.game

        switch state.state {
        case .idle:
            break

        case .startServer:
            if server == nil {
                server = SpaceWarServer(engine: engine, controller: controller, name: steam.localServerName)
            }

            if let server, server.isConnectedToSteam {
                // server is ready, connect to it
                connectTo(gameServerSteamID: server.steamID)
            }

        case .connecting:
            // Draw text telling the user a connection attempt is in progress
            clientLayout.drawConnectionAttemptText(secondsLeft: clientConnection.secondsLeftToConnect,
                                                   connectingToWhat: "server")

        case .connectionFailure:
            guard let failureReason = clientConnection.connectionError else {
                preconditionFailure("Don't know why connection failed")
            }
            clientLayout.drawConnectionFailureText(failureReason)
            if escapePressed {
                frameRc = .mainMenu
            }

        case .active:
            // Make sure the Steam Controller is in the correct mode.
            controller.setActionSet(.shipControls)

            // SendHeartbeat is safe to call on every frame since the API is internally rate-limited.
            // Ideally you would only call this once per second though, to minimize unnecessary calls.
            steam.inventory.sendItemDropHeartbeat()

            // Update all the entities...
            sun.runFrame()
            gameState.ships.forEach { $0?.runFrame() }
//
//            for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
//            {
//                if (m_rgpWorkshopItems[i])
//                    m_rgpWorkshopItems[i]->RunFrame();
//            }

//            DrawHUDText();
//
            statsAndAchievements.runFrame()

            voiceChat.runFrame()

            if escapePressed {
                state.set(.quitMenu)
            }

        case .draw, .winner, .waitingForPlayers:
            // Update all the entities (this is client side interpolation)...
            sun.runFrame()
            gameState.ships.forEach { $0?.runFrame() }
//
//            DrawHUDText();
            clientLayout.drawWinnerDrawOrWaitingText(state: state, winner: gameState.playerSteamIDs[gameState.playerWhoWonGame])

            voiceChat.runFrame()

            if escapePressed {
                state.set(.quitMenu)
            }

        case .quitMenu:
            // Update all the entities (this is client side interpolation)...
            sun.runFrame()
            gameState.ships.forEach { $0?.runFrame() }

            // Now draw the menu
            quitMenu.runFrame()

            // Make sure the Steam Controller is in the correct mode.
            controller.setActionSet(.menuControls)
    
            if escapePressed {
                state.set(.active) // hmm
            } else if let quitChoice = quitMenu.selectedMenuItem {
                switch quitChoice {
                case .mainMenu: frameRc = .mainMenu
                case .quit: frameRc = .quit
                case .resume: state.set(.active) // hmm
                }
            }
        }

        // Send an update on our local ship to the server
        if clientConnection.isFullyConnected,
           let ship = gameState.ships[gameState.playerShipIndex],
           let update = ship.getClientUpdateData() {
            let msg = MsgClientSendLocalUpdate(shipPosition: gameState.playerShipIndex, update: update)

            // Send update as unreliable message.  This means that if network packets drop,
            // the networking system will not attempt retransmission, and our message may not arrive.
            // That's OK, because we would rather just send a new, update message, instead of
            // retransmitting the old one.
            clientConnection.sendServerData(msg: msg, sendFlags: .unreliable)
        }

        if !p2pAuthedGame.runFrame(server: server) {
            clientConnection.disconnect(reason: "Server failed P2P authentication")
            frameRc = .mainMenu
        }

        // If we've started a local server run it
        server?.runFrame()

        // Accumulate stats
        gameState.ships.forEach { $0?.accumulateStats(statsAndAchievements) }

        // Finally Render everything that might have been updated by the server
        switch state.state {
        case .draw, .winner, .active:
            sun.render()
            gameState.ships.forEach { $0?.render() }
//
//            for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
//            {
//                if ( m_rgpWorkshopItems[i] )
//                    m_rgpWorkshopItems[i]->Render();
//            }
            break

        default:
            // Any needed drawing was already done above before server updates
            break
        }

        if frameRc != .game {
            clientConnection.terminate()
            disconnect()
            server = nil
            state.set(.idle)
        }
        return frameRc
    }

    /// Receives incoming network data
    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
        clientConnection.receiveMessages() { msg, size, data in
            switch msg {
            case .serverSendInfo, .serverFailAuthentication, .serverExiting:
                preconditionFailure("Unexpected connection message \(msg)")

            case .serverPassAuthentication:
                // All connected, ready to play!
                let authMsg = MsgServerPassAuthentication(data: data)
                gameState.playerShipIndex = Int(authMsg.playerPosition)
                // tell steam china duration control system that we are in a match and not to be interrupted
                _ = steam.user.setDurationControlOnlineState(newState: .onlineHighPri)

            case .serverUpdateWorld:
                guard size == MsgServerUpdateWorld.networkSize else {
                    OutputDebugString("SpaceWarClient bad message size MsgServerUpdateWorld \(size)")
                    return
                }
                onReceiveServerUpdate(msg: MsgServerUpdateWorld(data: data))

            case .voiceChatData:
                // This is really bad exmaple code that just assumes the message is the right size
                // Don't ship code like this.
                voiceChat.handleVoiceChatData(msg: MsgVoiceChatData(data: data))

            case .P2PSendingTicket:
                // This is really bad exmaple code that just assumes the message is the right size
                // Don't ship code like this.
                p2pAuthedGame.handleP2PSendingTicket(msg: MsgP2PSendingTicket(data: data))

            default:
                OutputDebugString("Unhandled message from server \(msg)")
            }
        }

        // if we're running a server, do that as well
        server?.receiveNetworkData()
    }

    // MARK: Game Data Utilities

    /// For a player in game, set the appropriate rich presence keys for display in the Steam friends list
    func setInGameRichPresence() {
        var winning = false
        var winners = 0
        var highScore = gameState.playerScores[0]
        var myScore = UInt32.min

        for i in 0..<Misc.MAX_PLAYERS_PER_SERVER {
            if gameState.playerScores[i] > highScore {
                highScore = gameState.playerScores[i]
                winners = 0
                winning = false
            }

            if gameState.playerScores[i] == highScore {
                winners += 1
                winning = winning || gameState.playerSteamIDs[i] == steam.user.getSteamID()
            }

            if gameState.playerSteamIDs[i] == steam.user.getSteamID() {
                myScore = gameState.playerScores[i]
            }
        }
        // so why does this nonsense not trust 'playerShipIndex' but does trust
        // the steamID array?  Server quirk or historical cargo culting, tbd

        let status: RichPresence.GameStatus

        if winning && winners > 1 {
            status = .tied
        } else if winning {
            status = .winning
        } else {
            status = .losing
        }

        steam.friends.setRichPresence(gameStatus: status, score: myScore)
    }

    /// Did we win the last game?
    var localPlayerWonLastGame: Bool {
        guard state.state == .winner,
              let ship = gameState.ships[gameState.playerWhoWonGame] else {
            return false
        }
        return ship.isLocalPlayer
    }

    // MARK: Server/Client data update

    /// Handles receiving a state update from the game server
    func onReceiveServerUpdate(msg: MsgServerUpdateWorld) {
        // Update our client state based on what the server tells us

        if state.state != .quitMenu {
            switch msg.currentGameState {
            case .waitingForPlayers: state.set(.waitingForPlayers)
            case .active: state.set(.active)
            case .draw: state.set(.draw)
            case .winner: state.set(.winner)
            }
        }

        // Update scores
        gameState.playerScores = msg.playerScores
        // Update who won last
        gameState.playerWhoWonGame = msg.playerWhoWonGame

        // Update p2p authentication as we learn about the peers
        p2pAuthedGame.onReceive(msg: msg, isOwner: server != nil, gameState: gameState)

        // update all players that are active
        voiceChat.markAllPlayersInactive()

        // Update steamid array with data from server
        gameState.playerSteamIDs = msg.playerSteamIDs

        // Update the players
        for i in 0..<Misc.MAX_PLAYERS_PER_SERVER {
            guard msg.playersActive[i] else {
                // Make sure we don't have a ship locally for this slot
                gameState.ships[i] = nil
                return
            }

            // Check if we have a ship created locally for this player slot, if not create it
            if gameState.ships[i] == nil {
                let shipData = msg.shipData[i]
                let ship = Ship(engine: engine,
                                controller: controller,
                                isServerInstance: false,
                                pos: shipData.position * engine.viewportSize,
                                color: Misc.PlayerColors[i])
                gameState.ships[i] = ship

                if i == gameState.playerShipIndex {
                    OutputDebugString("SpaceWarClient - Creating our local ship")
                    // If this is our local ship, then setup key bindings appropriately
                    ship.vkLeft = .printable("A")
                    ship.vkRight = .printable("D")
                    ship.vkForwardThrusters = .printable("W")
                    ship.vkReverseThrusters = .printable("S")
                    ship.vkFire = .printable(" ")
                }
            }

            gameState.ships[i]!.isLocalPlayer = (i == gameState.playerShipIndex)
            gameState.ships[i]!.onReceiveServerUpdate(data: msg.shipData[i])

            voiceChat.markPlayerAsActive(steamID: gameState.playerSteamIDs[i])
        }
    }
}

extension SteamAPI {
    /// String used for game servers spun up by this session
    var localServerName: String {
        "\(friends.getPersonaName())'s game"
    }
}
