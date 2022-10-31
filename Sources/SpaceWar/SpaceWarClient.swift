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

    /// A local server we mayt be running
    private var server: SpaceWarServer?

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
        var playerScores: [Int]
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

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam
        self.state = .init(tickSource: engine, initial: .idle, name: "Client")
        self.clientConnection = SpaceWarClientConnection(steam: steam, tickSource: engine)
        self.clientLayout = SpaceWarClientLayout(steam: steam, engine: engine)
        self.p2pAuthedGame = P2PAuthedGame(steam: steam, tickSource: engine, connection: clientConnection)
        self.server = nil

        self.gameState = GameState()

        //    // Initialize pause menu
        //    m_pQuitMenu = new CQuitMenu( pGameEngine );
        //
        //    // Initialize sun
        //    m_pSun = new CSun( pGameEngine );
        //
        //    m_nNumWorkshopItems = 0;
        //    for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
        //    {
        //        m_rgpWorkshopItems[i] = NULL;
        //    }
        //
        //    // Voice chat
        //    m_pVoiceChat = new CVoiceChat( pGameEngine );
        //    LoadWorkshopItems();
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
            //        m_pLeaderboards->UpdateLeaderboards( m_pStatsAndAchievements );
            //
            //        // Check if the user is due for an item drop
            //        SpaceWarLocalInventory()->CheckForItemDrops();
            setInGameRichPresence()

        case .active:
            //        // Load Inventory
            //        SpaceWarLocalInventory()->RefreshFromServer();
            //
            //        // start voice chat
            //        m_pVoiceChat->StartVoiceChat();
            //        m_pVoiceChat->m_hConnServer = m_hConnServer;
            //
            setInGameRichPresence()

        case .connectionFailure:
            disconnect() // leave game_status rich presence where it was before I guess

        default:
            steam.friends.setRichPresence(gameStatus: .waitingForMatch)
        }

        steam.friends.setRichPresence(status: state.state.richPresenceStatus)

        // update network-related rich presence state and steam_player_group
        clientConnection.updateRichPresence()

        //    // Let the stats handler check the state (so it can detect wins, losses, etc...)
        //    XXX m_pStatsAndAchievements->OnGameStateChange( eState );
    }

    /// Cilent tasks to be done on disconnecting from a server - not in a state-change because can
    /// happen at weird times like object deletion.
    func disconnect() {
        p2pAuthedGame.endGame()
        // XXX voiceChat.endGame()
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

        if let serverName = clientConnection.serverName {
            //    m_pQuitMenu->SetHeading( serverName ); XXX
        }

        var frameRc = FrameRc.game

        switch state.state {
        case .idle:
            break

        case .startServer:
            if server == nil {
                server = SpaceWarServer(engine: engine, name: steam.localServerName)
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
            // XXX SteamInput m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_ShipControls );

            // SendHeartbeat is safe to call on every frame since the API is internally rate-limited.
            // Ideally you would only call this once per second though, to minimize unnecessary calls.
            // XXX inventory SteamInventory()->SendItemDropHeartbeat();

            // Update all the entities...
//            sun.runFrame()
//            for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
//            {
//                if ( m_rgpShips[i] )
//                    m_rgpShips[i]->RunFrame();
//            }
//
//            for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
//            {
//                if (m_rgpWorkshopItems[i])
//                    m_rgpWorkshopItems[i]->RunFrame();
//            }

//            DrawHUDText();
//
//            m_pStatsAndAchievements->RunFrame();
//
//            m_pVoiceChat->RunFrame();

            if escapePressed {
                state.set(.quitMenu)
            }

        case .draw, .winner, .waitingForPlayers:
            // Update all the entities (this is client side interpolation)...
//            m_pSun->RunFrame();
//            for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
//            {
//                if ( m_rgpShips[i] )
//                    m_rgpShips[i]->RunFrame();
//            }
//
//            DrawHUDText();
//            DrawWinnerDrawOrWaitingText();
//
//            m_pVoiceChat->RunFrame();

            if escapePressed {
                state.set(.quitMenu)
            }

        case .quitMenu:
            // Update all the entities (this is client side interpolation)...
//            m_pSun->RunFrame();
//            for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
//            {
//                if ( m_rgpShips[i] )
//                    m_rgpShips[i]->RunFrame();
//            }
//
//            // Now draw the menu
//            m_pQuitMenu->RunFrame();

            // Make sure the Steam Controller is in the correct mode.
//  XXX SteamInput          m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_MenuControls );
            break;
        }

        // Send an update on our local ship to the server
        if clientConnection.isConnected /* XXX , let ship = ships[playerShipIndex] */{
        //        MsgClientSendLocalUpdate_t msg;
        //        msg.SetShipPosition( m_uPlayerShipIndex );
        //
        //        // Send update as unreliable message.  This means that if network packets drop,
        //        // the networking system will not attempt retransmission, and our message may not arrive.
        //        // That's OK, because we would rather just send a new, update message, instead of
        //        // retransmitting the old one.
        //        if ( m_rgpShips[ m_uPlayerShipIndex ]->BGetClientUpdateData( msg.AccessUpdateData() ) )
        //            BSendServerData( &msg, sizeof( msg ), k_nSteamNetworkingSend_Unreliable );
        }

        if !p2pAuthedGame.runFrame(server: server) {
            clientConnection.disconnect(reason: "Server failed P2P authentication")
            frameRc = .mainMenu
        }

        // If we've started a local server run it
        server?.runFrame()

        //    // Accumulate stats
        //    for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
        //    {
        //        if ( m_rgpShips[i] )
        //            m_rgpShips[i]->AccumulateStats( m_pStatsAndAchievements );
        //    }
        //   ships.forEach { $0?.accumulateStats(to: statsAndAchievements) }

        // Finally Render everything that might have been updated by the server
        switch state.state {
        case .draw, .winner, .active:
//            m_pSun->Render();
//            for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
//            {
//                if ( m_rgpShips[i] )
//                    m_rgpShips[i]->Render();
//            }
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

            //        case k_EMsgServerUpdateWorld:
            //        {
            //            if (cubMsgSize != sizeof(MsgServerUpdateWorld_t))
            //            {
            //                OutputDebugString("Bad server world update msg\n");
            //                break;
            //            }
            //
            //            MsgServerUpdateWorld_t* pMsg = (MsgServerUpdateWorld_t*)message->GetData();
            //            OnReceiveServerUpdate(pMsg->AccessUpdateData());
            //        }
            //        break;
            //
            //        case k_EMsgVoiceChatData:
            //            // This is really bad exmaple code that just assumes the message is the right size
            //            // Don't ship code like this.
            //            m_pVoiceChat->HandleVoiceChatData( message->GetData() );
            //            break;
            //
            //        case k_EMsgP2PSendingTicket:
            //            // This is really bad exmaple code that just assumes the message is the right size
            //            // Don't ship code like this.
            //            m_pP2PAuthedGame->HandleP2PSendingTicket( message->GetData() );
            //            break;

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
        var myScore = 0

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

// MARK: C++ Client Game Networking

////-----------------------------------------------------------------------------
//// Purpose: Handles receiving a state update from the game server
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnReceiveServerUpdate( ServerSpaceWarUpdateData_t *pUpdateData )
//{
//    // Update our client state based on what the server tells us
//
//    switch( pUpdateData->GetServerGameState() )
//    {
//    case k_EServerWaitingForPlayers:
//        if ( m_eGameState == k_EClientGameQuitMenu )
//            break;
//        else if (m_eGameState == k_EClientGameMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameExiting )
//            break;
//
//        SetGameState( k_EClientGameWaitingForPlayers );
//        break;
//    case k_EServerActive:
//        if ( m_eGameState == k_EClientGameQuitMenu )
//            break;
//        else if (m_eGameState == k_EClientGameMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameExiting )
//            break;
//
//        SetGameState( k_EClientGameActive );
//        break;
//    case k_EServerDraw:
//        if ( m_eGameState == k_EClientGameQuitMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameExiting )
//            break;
//
//        SetGameState( k_EClientGameDraw );
//        break;
//    case k_EServerWinner:
//        if ( m_eGameState == k_EClientGameQuitMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameMenu )
//            break;
//        else if ( m_eGameState == k_EClientGameExiting )
//            break;
//
//        SetGameState( k_EClientGameWinner );
//        break;
//    case k_EServerExiting:
//        if ( m_eGameState == k_EClientGameExiting )
//            break;
//
//        SetGameState( k_EClientGameMenu );
//        break;
//    }
//
//    // Update scores
//    for( int i=0; i < MAX_PLAYERS_PER_SERVER; ++i )
//    {
//        m_rguPlayerScores[i] = pUpdateData->GetPlayerScore(i);
//    }
//
//    // Update who won last
//    m_uPlayerWhoWonGame = pUpdateData->GetPlayerWhoWon();
//
//    // Update p2p authentication as we learn about the peers
//    p2pAuthedGame.onReceive(serverUpdate: updateData, isOwner: server != nil, gameState: gameState)
//
//    // update all players that are active
//    if ( m_pVoiceChat )
//        m_pVoiceChat->MarkAllPlayersInactive();
//
//    // Update the players
//    for( uint32 i=0; i < MAX_PLAYERS_PER_SERVER; ++i )
//    {
//        // Update steamid array with data from server
//        m_rgSteamIDPlayers[i].SetFromUint64( pUpdateData->GetPlayerSteamID( i ) );
//
//        if ( pUpdateData->GetPlayerActive( i ) )
//        {
//            // Check if we have a ship created locally for this player slot, if not create it
//            if ( !m_rgpShips[i] )
//            {
//                ServerShipUpdateData_t *pShipData = pUpdateData->AccessShipUpdateData( i );
//                m_rgpShips[i] = new CShip( m_pGameEngine, false, pShipData->GetXPosition(), pShipData->GetYPosition(), g_rgPlayerColors[i] );
//                if ( i == m_uPlayerShipIndex )
//                {
//                    // If this is our local ship, then setup key bindings appropriately
//                    m_rgpShips[i]->SetVKBindingLeft( 0x41 ); // A key
//                    m_rgpShips[i]->SetVKBindingRight( 0x44 ); // D key
//                    m_rgpShips[i]->SetVKBindingForwardThrusters( 0x57 ); // W key
//                    m_rgpShips[i]->SetVKBindingReverseThrusters( 0x53 ); // S key
//                    m_rgpShips[i]->SetVKBindingFire( VK_SPACE );
//                }
//            }
//
//            if ( i == m_uPlayerShipIndex )
//                m_rgpShips[i]->SetIsLocalPlayer( true );
//            else
//                m_rgpShips[i]->SetIsLocalPlayer( false );
//
//            m_rgpShips[i]->OnReceiveServerUpdate( pUpdateData->AccessShipUpdateData( i ) );
//
//            if ( m_pVoiceChat )
//                m_pVoiceChat->MarkPlayerAsActive( m_rgSteamIDPlayers[i] );
//        }
//        else
//        {
//            // Make sure we don't have a ship locally for this slot
//            if ( m_rgpShips[i] )
//            {
//                delete m_rgpShips[i];
//                m_rgpShips[i] = NULL;
//            }
//        }
//    }
//}
}

extension SteamAPI {
    /// String used for game servers spun up by this session
    var localServerName: String {
        "\(friends.getPersonaName())'s game"
    }
}
