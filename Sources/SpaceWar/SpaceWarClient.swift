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
    /// Time we last got any data from the server
    private var lastNetworkDataReceivedTime: Engine2D.TickCount
    /// Server address details - IP address
    private var serverIP: Int
    /// Server address details - IP port
    private var serverPort: UInt16
    /// Server authentication ticket
    private var authTicket: HAuthTicket

    /// A local server we may or may not be running
    private var server: SpaceWarServer?

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam
        self.state = .init(tickSource: engine, initial: .idle)
        self.clientConnection = SpaceWarClientConnection(steam: steam, tickSource: engine)
        self.lastNetworkDataReceivedTime = 0
        self.serverIP = 0
        self.serverPort = 0
        self.authTicket = .invalid
        self.server = nil

        //    m_uPlayerWhoWonGame = 0;
        //    m_uPlayerShipIndex = 0;
        //    for( uint32 i = 0; i < MAX_PLAYERS_PER_SERVER; ++i )
        //    {
        //        m_rguPlayerScores[i] = 0;
        //        m_rgpShips[i] = NULL;
        //    }
        //    m_hHUDFont = pGameEngine->HCreateFont( HUD_FONT_HEIGHT, FW_BOLD, false, "Arial" );
        //    if ( !m_hHUDFont )
        //        OutputDebugString( "HUD font was not created properly, text won't draw\n" );
        //
        //    m_hInstructionsFont = pGameEngine->HCreateFont( INSTRUCTIONS_FONT_HEIGHT, FW_BOLD, false, "Arial" );
        //    if ( !m_hInstructionsFont )
        //        OutputDebugString( "instruction font was not created properly, text won't draw\n" );

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
        //    // initialize P2P auth engine
        //    m_pP2PAuthedGame = new CP2PAuthedGame( m_pGameEngine );
        //    // P2P voice chat
        //    m_pVoiceChat = new CVoiceChat( pGameEngine );
        //    LoadWorkshopItems();
    }

    deinit {
        //    DisconnectFromServer();
        //
        //    if ( m_pP2PAuthedGame )
        //    {
        //        m_pP2PAuthedGame->EndGame();
        //        delete m_pP2PAuthedGame;
        //        m_pP2PAuthedGame = NULL;
        //    }
    }

    // MARK: Kick-off entrypoints

    /// User hits 'start server' on the main menu.
    /// Create a new local server, wait for it to be ready, connect to it.
    func startServer() {
        precondition(state.state == .idle, "Must be .idle on StartServer not \(state)") // I think...
        state.set(.startServer)
    }

    /// User has found/started a server via a lobby, we take over now.
    func connectFromLobby(steamID: SteamID, server: Int? /*SpaceWarServer*/) {
        precondition(state.state == .idle, "Must be .idle on StartServer not \(state)") // I think...
        state.set(.startServer) /* XXX */
    }

    func execCommandLineConnect(params: CmdLineParams) {
        print("ExecCommandLineConnect: \(params)")
    }

    // MARK: State machine

    func onStateChanged() {
        //    if ( m_eGameState == k_EClientGameWinner || m_eGameState == k_EClientGameDraw )
        //    {
        //        // game over.. update the leaderboard
        //        m_pLeaderboards->UpdateLeaderboards( m_pStatsAndAchievements );
        //
        //        // Check if the user is due for an item drop
        //        SpaceWarLocalInventory()->CheckForItemDrops();
        //        SetInGameRichPresence();
        //    }

        //    else if ( m_eGameState == k_EClientGameActive )
        //    {
        //        // Load Inventory
        //        SpaceWarLocalInventory()->RefreshFromServer();
        //
        //        // start voice chat
        //        m_pVoiceChat->StartVoiceChat(); Pass In clientConnection.conn, update P2P thing too
        //
        //        SetInGameRichPresence();
        //    }

        //    else {
        steam.friends.setRichPresence(gameStatus: .waitingForMatch)
        //    }

        steam.friends.setRichPresence(status: state.state.richPresenceStatus)

        //    // steam_player_group defines who the user is playing with.  Set it to the steam ID
        //    // of the server if we are connected, otherwise blank.
        //    if ( m_steamIDGameServer.IsValid() )
        //    {
        //        SteamFriends()->SetRichPresence(playerGroup: m_steamIDGameServer)
        //    } else {
        //        SteamFriends().SetRichPresence(playerGroup: nil)
        //    }

        // XXX might need to factor this out, called elsewhere too
        //    // update any network-related rich presence state
        //    if ( m_eConnectedStatus == k_EClientConnectedAndAuthenticated && m_unServerIP && m_usServerPort )
        //    {
        //        // game server connection method
        //        steam.friends.setRichPresence(connectedTo: .server(0, 0))
        //    }
        //    else {
        steam.friends.setRichPresence(connectedTo: .nothing)
        //    }

        //    // Let the stats handler check the state (so it can detect wins, losses, etc...)
        //    XXX m_pStatsAndAchievements->OnGameStateChange( eState );
    }

    /// Frame poll function.
    /// Called by `SpaceWarMain` when it thinks we're in a state of running/starting a game.
    /// Return what we want to do next.
    enum FrameRc {
        case game // stay in game mode
        case mainMenu // quit back to mainMenu
        case quit // quit to desktop
    }

    func runFrame() -> FrameRc {
        precondition(state.state != .idle, "SpaceWarMain thinks we're busy but we're idle :-(")

        //    if ( clientConnection.isConnected && m_pGameEngine->GetGameTickCount() - m_ulLastNetworkDataReceivedTime > MILLISECONDS_CONNECTION_TIMEOUT )
        //    {
        //        SetConnectionFailureText( "Game server connection failure." );
        //        DisconnectFromServer(); // cleanup on our side, even though server won't get our disconnect msg
        //        SetGameState( k_EClientGameConnectionFailure );
        //    }

        // if we just transitioned state, perform on change handlers
        state.onTransition {
            onStateChanged()
        }

        switch state.state {
            //    case k_EClientGameConnectionFailure:
            //        DrawConnectionFailureText();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //
            //        break;
            //    case k_EClientGameConnecting:
            //        // Draw text telling the user a connection attempt is in progress
            //        DrawConnectionAttemptText();
            //
            //        // Check if we've waited too long and should time out the connection
            //        if clientConnection.testConnectionTimeout() {
            //            SetGameState( k_EClientGameConnectionFailure );
            //        }
            //        break;
            //    case k_EClientGameQuitMenu:
            //        // Update all the entities (this is client side interpolation)...
            //        m_pSun->RunFrame();
            //        for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
            //        {
            //            if ( m_rgpShips[i] )
            //                m_rgpShips[i]->RunFrame();
            //        }
            //
            //        // Now draw the menu
            //        m_pQuitMenu->RunFrame();
            //
            //        // Make sure the Steam Controller is in the correct mode.
            //        m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_MenuControls );
            //        break;
            //    case k_EClientGameStartServer:
            //        if ( !m_pServer )
            //        {
            //            m_pServer = new CSpaceWarServer( m_pGameEngine );
            //        }
            //
            //        if ( m_pServer && m_pServer->IsConnectedToSteam() )
            //        {
            //            // server is ready, connect to it
            //            InitiateServerConnection( m_pServer->GetSteamID() );
            //        }
            //        break;
            //    case k_EClientGameDraw:
            //    case k_EClientGameWinner:
            //    case k_EClientGameWaitingForPlayers:
            //        // Update all the entities (this is client side interpolation)...
            //        m_pSun->RunFrame();
            //        for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
            //        {
            //            if ( m_rgpShips[i] )
            //                m_rgpShips[i]->RunFrame();
            //        }
            //
            //        DrawHUDText();
            //        DrawWinnerDrawOrWaitingText();
            //
            //        m_pVoiceChat->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameQuitMenu );
            //        break;
            //
            //    case k_EClientGameActive:
            //        // Make sure the Steam Controller is in the correct mode.
            //        m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_ShipControls );
            //
            //        // SendHeartbeat is safe to call on every frame since the API is internally rate-limited.
            //        // Ideally you would only call this once per second though, to minimize unnecessary calls.
            //        SteamInventory()->SendItemDropHeartbeat();
            //
            //        // Update all the entities...
            //        m_pSun->RunFrame();
            //        for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
            //        {
            //            if ( m_rgpShips[i] )
            //                m_rgpShips[i]->RunFrame();
            //        }
            //
            //        for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
            //        {
            //            if (m_rgpWorkshopItems[i])
            //                m_rgpWorkshopItems[i]->RunFrame();
            //        }
            //
            //        DrawHUDText();
            //
            //        m_pStatsAndAchievements->RunFrame();
            //
            //        m_pVoiceChat->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameQuitMenu );
            //        break;
        default:
            break
        }

        //    // Send an update on our local ship to the server
        //    if ( m_eConnectedStatus == k_EClientConnectedAndAuthenticated &&  m_rgpShips[ m_uPlayerShipIndex ] )
        //    {
        //        MsgClientSendLocalUpdate_t msg;
        //        msg.SetShipPosition( m_uPlayerShipIndex );
        //
        //        // Send update as unreliable message.  This means that if network packets drop,
        //        // the networking system will not attempt retransmission, and our message may not arrive.
        //        // That's OK, because we would rather just send a new, update message, instead of
        //        // retransmitting the old one.
        //        if ( m_rgpShips[ m_uPlayerShipIndex ]->BGetClientUpdateData( msg.AccessUpdateData() ) )
        //            BSendServerData( &msg, sizeof( msg ), k_nSteamNetworkingSend_Unreliable );
        //    }
        //
        //    if ( m_pP2PAuthedGame )
        //    {
        //        if ( m_pServer )
        //        {
        //            // Now if we are the owner of the game, lets make sure all of our players are legit.
        //            // if they are not, we tell the server to kick them off
        //            // Start at 1 to skip myself
        //            for ( int i = 1; i < MAX_PLAYERS_PER_SERVER; i++ )
        //            {
        //                if ( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i] && !m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i]->BIsAuthOk() )
        //                {
        //                    m_pServer->KickPlayerOffServer( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[i]->m_steamID );
        //                }
        //            }
        //        }
        //        else
        //        {
        //            // If we are not the owner of the game, lets make sure the game owner is legit
        //            // if he is not, we leave the game
        //            if ( m_pP2PAuthedGame->m_rgpP2PAuthPlayer[0] )
        //            {
        //                if ( !m_pP2PAuthedGame->m_rgpP2PAuthPlayer[0]->BIsAuthOk() )
        //                {
        //                    // leave the game
        //                    SetGameState( k_EClientGameMenu );
        //                }
        //            }
        //        }
        //    }
        //
        //    // If we've started a local server run it
        //    if ( m_pServer )
        //    {
        //        m_pServer->RunFrame();
        //    }
        //
        //    // Accumulate stats
        //    for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
        //    {
        //        if ( m_rgpShips[i] )
        //            m_rgpShips[i]->AccumulateStats( m_pStatsAndAchievements );
        //    }
        //
        //    // Render everything that might have been updated by the server
        //    switch ( m_eGameState )
        //    {
        //    case k_EClientGameDraw:
        //    case k_EClientGameWinner:
        //    case k_EClientGameActive:
        //        // Now render all the objects
        //        m_pSun->Render();
        //        for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
        //        {
        //            if ( m_rgpShips[i] )
        //                m_rgpShips[i]->Render();
        //        }
        //
        //        for (uint32 i = 0; i < MAX_WORKSHOP_ITEMS; ++i)
        //        {
        //            if ( m_rgpWorkshopItems[i] )
        //                m_rgpWorkshopItems[i]->Render();
        //        }
        //
        //        break;
        //    default:
        //        // Any needed drawing was already done above before server updates
        //        break;
        //    }

        return .mainMenu
    }

    /// Receives incoming network data
    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
        if FAKE_NET_USE {
            receiveNetworkData_fake()
        } else {
            receiveNetworkData_real()
        }

        // if we're running a server, do that as well
        server?.receiveNetworkData()
    }

    func receiveNetworkData_fake() {
        guard clientConnection.serverSteamID != nil else {
            return
        }

        while let message = FakeNet.recv(at: steam.user.getSteamID()) {
            lastNetworkDataReceivedTime = engine.gameTickCount
            switch message.type {
            case .client:
                let clientMsg = message as! FakeClientMsg
                receiveNetworkData(size: clientMsg.size, data: clientMsg.body)
                clientMsg.release()
            case .connect:
                preconditionFailure("Bad fakenet message on client: \(message)")
            }
        }
    }

    func receiveNetworkData(size: Int, data: UnsafeMutableRawPointer) {
        guard size > MemoryLayout<UInt32>.size else {
            OutputDebugString("Got garbage on client socket, too short")
            return
        }

        guard let msg = Unpack.msgDword(data) else {
            OutputDebugString("Got garbage on client socket, bad msg cookie")
            return
        }

        if clientConnection.receive(msg: msg, size: size, data: data) {
            // handled by connection layer
            return
        }

        switch msg {
        case .serverSendInfo:
            preconditionFailure("Unexpected connection message \(msg)")
        //        case k_EMsgServerPassAuthentication:
        //        {
        //            if (cubMsgSize != sizeof(MsgServerPassAuthentication_t))
        //            {
        //                OutputDebugString("Bad accept connection msg\n");
        //                break;
        //            }
        //            MsgServerPassAuthentication_t* pMsg = (MsgServerPassAuthentication_t*)message->GetData();
        //
        //            // Our game client doesn't really care about whether the server is secure, or what its
        //            // steamID is, but if it did we would pass them in here as they are part of the accept message
        //            OnReceiveServerAuthenticationResponse(true, pMsg->GetPlayerPosition());
        //        }
        //        break;
        //        case k_EMsgServerFailAuthentication:
        //        {
        //            OnReceiveServerAuthenticationResponse(false, 0);
        //        }
        //        break;
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
        //        case k_EMsgServerExiting:
        //        {
        //            if (cubMsgSize != sizeof(MsgServerExiting_t))
        //            {
        //                OutputDebugString("Bad server exiting msg\n");
        //            }
        //            OnReceiveServerExiting();
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

    func receiveNetworkData_real() {
        guard let connServer = clientConnection.netConnection else {
            return
        }

        let rc = steam.networkingSockets.receiveMessagesOnConnection(conn: connServer, maxMessages: 32)
        rc.messages.forEach { message in
            lastNetworkDataReceivedTime = engine.gameTickCount

            // make sure we're connected
            if clientConnection.isConnected || state.state == .connecting {
                receiveNetworkData(size: message.size, data: message.data)
            } else {
                OutputDebugString("Ignoring message in weird state \(state.state)")
            }

            message.release()
        }
    }

    /// For a player in game, set the appropriate rich presence keys for display in the Steam friends list
    func setInGameRichPresence() {
    //    const char *pchStatus;
    //
    //    bool bWinning = false;
    //    uint32 cWinners = 0;
    //    uint32 uHighScore = m_rguPlayerScores[0];
    //    uint32 uMyScore = 0;
    //    for ( uint32 i = 0; i < MAX_PLAYERS_PER_SERVER; ++i )
    //    {
    //        if ( m_rguPlayerScores[i] > uHighScore )
    //        {
    //            uHighScore = m_rguPlayerScores[i];
    //            cWinners = 0;
    //            bWinning = false;
    //        }
    //
    //        if ( m_rguPlayerScores[i] == uHighScore )
    //        {
    //            cWinners++;
    //            bWinning = bWinning || (m_rgSteamIDPlayers[i] == m_SteamIDLocalUser);
    //        }
    //
    //        if ( m_rgSteamIDPlayers[i] == m_SteamIDLocalUser )
    //        {
    //            uMyScore = m_rguPlayerScores[i];
    //        }
    //    }
    //
    //    if ( bWinning && cWinners > 1 )
    //    {
    //        pchStatus = "Tied";
    //    }
    //    else if ( bWinning )
    //    {
    //        pchStatus = "Winning";
    //    }
    //    else
    //    {
    //        pchStatus = "Losing";
    //    }
    //
    //    char rgchBuffer[32];
    //    sprintf_safe( rgchBuffer, "%2u", uMyScore );
    //    SteamFriends()->SetRichPresence( "score", rgchBuffer );
    //
    //    return pchStatus;

        steam.friends.setRichPresence(gameStatus: .losing/*XXXpchStatus*/, score: 0/*XXXuMyScore*/)
    }

    /// Tell the connected server we are disconnecting (if we are connected)
    func disconnectFromServer() {
        clientConnection.disconnect(reason: "XXX disconnect me")
        // tell steam china duration control system that we are no longer in a match
        _ = steam.user.setDurationControlOnlineState(newState: .offline)
        //    if ( m_pP2PAuthedGame )
        //    {
        //        m_pP2PAuthedGame->EndGame();
        //    }
        //
        //    if ( m_pVoiceChat )
        //    {
        //        m_pVoiceChat->StopVoiceChat();
        //    }
    }

// MARK: C++ UI Layout

//// Height of the HUD font
//#define HUD_FONT_HEIGHT 18
//
//// Height for the instructions font
//#define INSTRUCTIONS_FONT_HEIGHT 24
//

//    // Draw the HUD text (should do this after drawing all the objects)
//    void DrawHUDText();
//
//    // Draw instructions for how to play the game
//    void DrawInstructions();
//
//    // Draw text telling the players who won (or that their was a draw)
//    void DrawWinnerDrawOrWaitingText();
//
//    // Draw text telling the user that the connection attempt has failed
//    void DrawConnectionFailureText();
//
//    // Draw connect to server text
//    void DrawConnectToServerText();
//
//    // Draw text telling the user a connection attempt is in progress
//    void DrawConnectionAttemptText();

//    // Font handle for drawing the HUD text
//    HGAMEFONT m_hHUDFont;
//
//    // Font handle for drawing the instructions text
//    HGAMEFONT m_hInstructionsFont;

////-----------------------------------------------------------------------------
//// Purpose: Draws some HUD text indicating game status
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawHUDText()
//{
//    // Padding from the edge of the screen for hud elements
//#ifdef _PS3
//    // Larger padding on PS3, since many of our test HDTVs truncate
//    // edges of the screen and can't be calibrated properly.
//    const int32 nHudPaddingVertical = 20;
//    const int32 nHudPaddingHorizontal = 35;
//#else
//    const int32 nHudPaddingVertical = 15;
//    const int32 nHudPaddingHorizontal = 15;
//#endif
//
//
//    const int32 width = m_pGameEngine->GetViewportWidth();
//    const int32 height = m_pGameEngine->GetViewportHeight();
//
//    const int32 nAvatarWidth = 64;
//    const int32 nAvatarHeight = 64;
//
//    const int32 nSpaceBetweenAvatarAndScore = 6;
//
//    LONG scorewidth = LONG((m_pGameEngine->GetViewportWidth() - nHudPaddingHorizontal*2.0f)/4.0f);
//
//    char rgchBuffer[256];
//    for( uint32 i=0; i<MAX_PLAYERS_PER_SERVER; ++i )
//    {
//        // Draw nothing in the spot for an inactive player
//        if ( !m_rgpShips[i] )
//            continue;
//
//
//        // We use Steam persona names for our players in-game name.  To get these we
//        // just call SteamFriends()->GetFriendPersonaName() this call will work on friends,
//        // players on the same game server as us (if using the Steam game server auth API)
//        // and on ourself.
//        char rgchPlayerName[128];
//        CSteamID playerSteamID( m_rgSteamIDPlayers[i] );
//
//        const char *pszVoiceState = m_pVoiceChat->IsPlayerTalking( playerSteamID ) ? "(VoiceChat)" : "";
//
//        if ( m_rgSteamIDPlayers[i].IsValid() )
//        {
//            sprintf_safe( rgchPlayerName, "%s", SteamFriends()->GetFriendPersonaName( playerSteamID ) );
//        }
//        else
//        {
//            sprintf_safe( rgchPlayerName, "Unknown Player" );
//        }
//
//        // We also want to use the Steam Avatar image inside the HUD if it is available.
//        // We look it up via GetMediumFriendAvatar, which returns an image index we use
//        // to look up the actual RGBA data below.
//        int iImage = SteamFriends()->GetMediumFriendAvatar( playerSteamID );
//        HGAMETEXTURE hTexture = 0;
//        if ( iImage != -1 )
//            hTexture = GetSteamImageAsTexture( iImage );
//
//        RECT rect;
//        switch( i )
//        {
//        case 0:
//            rect.top = nHudPaddingVertical;
//            rect.bottom = rect.top+nAvatarHeight;
//            rect.left = nHudPaddingHorizontal;
//            rect.right = rect.left + scorewidth;
//
//            if ( hTexture )
//            {
//                m_pGameEngine->BDrawTexturedRect( (float)rect.left, (float)rect.top, (float)rect.left+nAvatarWidth, (float)rect.bottom,
//                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
//                rect.left += nAvatarWidth + nSpaceBetweenAvatarAndScore;
//                rect.right += nAvatarWidth + nSpaceBetweenAvatarAndScore;
//            }
//
//            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
//            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_LEFT|TEXTPOS_VCENTER, rgchBuffer );
//            break;
//        case 1:
//
//            rect.top = nHudPaddingVertical;
//            rect.bottom = rect.top+nAvatarHeight;
//            rect.left = width-nHudPaddingHorizontal-scorewidth;
//            rect.right = width-nHudPaddingHorizontal;
//
//            if ( hTexture )
//            {
//                m_pGameEngine->BDrawTexturedRect( (float)rect.right - nAvatarWidth, (float)rect.top, (float)rect.right, (float)rect.bottom,
//                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
//                rect.right -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
//                rect.left -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
//            }
//
//            sprintf_safe( rgchBuffer, "%s\nScore: %2u ", rgchPlayerName, m_rguPlayerScores[i] );
//            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_RIGHT|TEXTPOS_VCENTER, rgchBuffer );
//            break;
//        case 2:
//            rect.top = height-nHudPaddingVertical-nAvatarHeight;
//            rect.bottom = rect.top+nAvatarHeight;
//            rect.left = nHudPaddingHorizontal;
//            rect.right = rect.left + scorewidth;
//
//            if ( hTexture )
//            {
//                m_pGameEngine->BDrawTexturedRect( (float)rect.left, (float)rect.top, (float)rect.left+nAvatarWidth, (float)rect.bottom,
//                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
//                rect.right += nAvatarWidth + nSpaceBetweenAvatarAndScore;
//                rect.left += nAvatarWidth + nSpaceBetweenAvatarAndScore;
//            }
//
//            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
//            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_LEFT|TEXTPOS_BOTTOM, rgchBuffer );
//            break;
//        case 3:
//            rect.top = height-nHudPaddingVertical-nAvatarHeight;
//            rect.bottom = rect.top+nAvatarHeight;
//            rect.left = width-nHudPaddingHorizontal-scorewidth;
//            rect.right = width-nHudPaddingHorizontal;
//
//            if ( hTexture )
//            {
//                m_pGameEngine->BDrawTexturedRect( (float)rect.right - nAvatarWidth, (float)rect.top, (float)rect.right, (float)rect.bottom,
//                    0.0f, 0.0f, 1.0, 1.0, D3DCOLOR_ARGB( 255, 255, 255, 255 ), hTexture );
//                rect.right -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
//                rect.left -= nAvatarWidth + nSpaceBetweenAvatarAndScore;
//            }
//
//            sprintf_safe( rgchBuffer, "%s\nScore: %2u %s", rgchPlayerName, m_rguPlayerScores[i], pszVoiceState );
//            m_pGameEngine->BDrawString( m_hHUDFont, rect, g_rgPlayerColors[i], TEXTPOS_RIGHT|TEXTPOS_BOTTOM, rgchBuffer );
//            break;
//        default:
//            OutputDebugString( "DrawHUDText() needs updating for more players\n" );
//            break;
//        }
//    }
//
//    // Draw a Steam Input tooltip
//    if ( m_pGameEngine->BIsSteamInputDeviceActive( ) )
//    {
//        char rgchHint[128];
//        const char *rgchFireOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_ShipControls, eControllerDigitalAction_FireLasers );
//
//        if ( strcmp( rgchFireOrigin, "None" ) == 0 )
//        {
//            sprintf_safe( rgchHint, "No Fire action bound." );
//        }
//        else
//        {
//            sprintf_safe( rgchHint, "Press '%s' to Fire", rgchFireOrigin );
//        }
//
//        RECT rect;
//        int nBorder = 30;
//        rect.top = m_pGameEngine->GetViewportHeight( ) - nBorder;
//        rect.bottom = m_pGameEngine->GetViewportHeight( )*2;
//        rect.left = nBorder;
//        rect.right = m_pGameEngine->GetViewportWidth( );
//        m_pGameEngine->BDrawString( m_hHUDFont, rect, D3DCOLOR_ARGB( 255, 255, 255, 255 ), TEXTPOS_LEFT | TEXTPOS_TOP, rgchHint );
//    }
//
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Draws some instructions on how to play the game
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawInstructions()
//{
//    const int32 width = m_pGameEngine->GetViewportWidth();
//
//    RECT rect;
//    rect.top = 0;
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//    rect.left = 0;
//    rect.right = width;
//
//    char rgchBuffer[256];
//#ifdef _PS3
//    sprintf_safe( rgchBuffer, "Turn Ship Left: 'Left'\nTurn Ship Right: 'Right'\nForward Thrusters: 'R2'\nReverse Thrusters: 'L2'\nFire Photon Beams: 'Cross'" );
//#else
//    sprintf_safe( rgchBuffer, "Turn Ship Left: 'A'\nTurn Ship Right: 'D'\nForward Thrusters: 'W'\nReverse Thrusters: 'S'\nFire Photon Beams: 'Space'" );
//#endif
//
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//
//
//    rect.left = 0;
//    rect.right = width;
//    rect.top = LONG(m_pGameEngine->GetViewportHeight() * 0.7);
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//
//    if ( m_pGameEngine->BIsSteamInputDeviceActive() )
//    {
//        const char *rgchActionOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_MenuControls, eControllerDigitalAction_MenuCancel );
//
//        if ( strcmp( rgchActionOrigin, "None" ) == 0 )
//        {
//            sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu. No controller button bound\n Build ID:%d", SteamApps()->GetAppBuildId() );
//        }
//        else
//        {
//            sprintf_safe( rgchBuffer, "Press ESC or '%s' to return the Main Menu\n Build ID:%d", rgchActionOrigin, SteamApps()->GetAppBuildId() );
//        }
//    }
//    else
//    {
//        sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu\n Build ID:%d", SteamApps()->GetAppBuildId() );
//    }
//
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_TOP, rgchBuffer );
//
//}
//
////-----------------------------------------------------------------------------
//// Purpose: Draws some text indicating a connection attempt is in progress
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawConnectionAttemptText()
//{
//    const int32 width = m_pGameEngine->GetViewportWidth();
//
//    RECT rect;
//    rect.top = 0;
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//    rect.left = 0;
//    rect.right = width;
//
//    // Figure out how long we are still willing to wait for success
//    uint32 uSecondsLeft = (MILLISECONDS_CONNECTION_TIMEOUT - uint32(m_pGameEngine->GetGameTickCount() - m_ulStateTransitionTime ))/1000;
//
//    char rgchTimeoutString[256];
//    if ( uSecondsLeft < 25 )
//        sprintf_safe( rgchTimeoutString, ", timeout in %u...\n", uSecondsLeft );
//    else
//        sprintf_safe( rgchTimeoutString, "...\n" );
//
//
//    char rgchBuffer[256];
//    if ( m_eGameState == k_EClientJoiningLobby )
//        sprintf_safe( rgchBuffer, "Connecting to lobby%s", rgchTimeoutString );
//    else
//        sprintf_safe( rgchBuffer, "Connecting to server%s", rgchTimeoutString );
//
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Draws some text indicating a connection failure
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawConnectionFailureText()
//{
//    const int32 width = m_pGameEngine->GetViewportWidth();
//
//    RECT rect;
//    rect.top = 0;
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//    rect.left = 0;
//    rect.right = width;
//
//    char rgchBuffer[256];
//    sprintf_safe( rgchBuffer, "%s\n", m_rgchErrorText );
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//
//    rect.left = 0;
//    rect.right = width;
//    rect.top = LONG(m_pGameEngine->GetViewportHeight() * 0.7);
//    rect.bottom = m_pGameEngine->GetViewportHeight();
//
//    if ( m_pGameEngine->BIsSteamInputDeviceActive() )
//    {
//        const char *rgchActionOrigin = m_pGameEngine->GetTextStringForControllerOriginDigital( eControllerActionSet_MenuControls, eControllerDigitalAction_MenuCancel );
//
//        if ( strcmp( rgchActionOrigin, "None" ) == 0 )
//        {
//            sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu. No controller button bound" );
//        }
//        else
//        {
//            sprintf_safe( rgchBuffer, "Press ESC or '%s' to return the Main Menu", rgchActionOrigin );
//        }
//    }
//    else
//    {
//        sprintf_safe( rgchBuffer, "Press ESC to return to the Main Menu" );
//    }
//    m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_TOP, rgchBuffer );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Draws some text about who just won (or that there was a draw)
////-----------------------------------------------------------------------------
//void CSpaceWarClient::DrawWinnerDrawOrWaitingText()
//{
//    int nSecondsToRestart = ((MILLISECONDS_BETWEEN_ROUNDS - (int)(m_pGameEngine->GetGameTickCount() - m_ulStateTransitionTime) )/1000) + 1;
//    if ( nSecondsToRestart < 0 )
//        nSecondsToRestart = 0;
//
//    RECT rect;
//    rect.top = 0;
//    rect.bottom = int(m_pGameEngine->GetViewportHeight()*0.6f);
//    rect.left = 0;
//    rect.right = m_pGameEngine->GetViewportWidth();
//
//    char rgchBuffer[256];
//    if ( m_eGameState == k_EClientGameWaitingForPlayers )
//    {
//        sprintf_safe( rgchBuffer, "Server is waiting for players.\n\nStarting in %d seconds...", nSecondsToRestart );
//        m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//    }
//    else if ( m_eGameState == k_EClientGameDraw )
//    {
//        sprintf_safe( rgchBuffer, "The round is a draw!\n\nStarting again in %d seconds...", nSecondsToRestart );
//        m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//    }
//    else if ( m_eGameState == k_EClientGameWinner )
//    {
//        if ( m_uPlayerWhoWonGame >= MAX_PLAYERS_PER_SERVER )
//        {
//            OutputDebugString( "Invalid winner value\n" );
//            return;
//        }
//
//        char rgchPlayerName[128];
//        if ( m_rgSteamIDPlayers[m_uPlayerWhoWonGame].IsValid() )
//        {
//            sprintf_safe( rgchPlayerName, "%s", SteamFriends()->GetFriendPersonaName( m_rgSteamIDPlayers[m_uPlayerWhoWonGame] ) );
//        }
//        else
//        {
//            sprintf_safe( rgchPlayerName, "Unknown Player" );
//        }
//
//        sprintf_safe( rgchBuffer, "%s wins!\n\nStarting again in %d seconds...", rgchPlayerName, nSecondsToRestart );
//
//        m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//    }
//
//    // Note: GetLastDroppedItem is the result of an async function, this will not render the reward right away. Could wait for it.
//    const CSpaceWarItem *pItem = SpaceWarLocalInventory()->GetLastDroppedItem();
//    if ( pItem )
//    {
//        // (We're not really bothering to localize everything else, this is just an example.)
//        sprintf_safe( rgchBuffer, "You won a brand new %s!", pItem->GetLocalizedName().c_str() );
//
//        rect.top = 0;
//        rect.bottom = int(m_pGameEngine->GetViewportHeight()*0.4f);
//        rect.left = 0;
//        rect.right = m_pGameEngine->GetViewportWidth();
//        m_pGameEngine->BDrawString( m_hInstructionsFont, rect, D3DCOLOR_ARGB( 255, 25, 200, 25 ), TEXTPOS_CENTER|TEXTPOS_VCENTER, rgchBuffer );
//    }
//}

// MARK: C++ Client Game Networking

//    // Send data to a client at the given ship index
//    bool BSendServerData( const void *pData, uint32 nSizeOfData, int nSendFlags );

//    void ExecCommandLineConnect( const char *pchServerAddress, const char *pchLobbyID );

//    // Receive a response from the server for a connection attempt
//    void OnReceiveServerAuthenticationResponse( bool bSuccess, uint32 uPlayerPosition );
//
//    // Recieved a response that the server is full
//    void OnReceiveServerFullResponse();
//
//    // Receive a state update from the server
//    void OnReceiveServerUpdate( ServerSpaceWarUpdateData_t *pUpdateData );
//
//    // Handle the server exiting
//    void OnReceiveServerExiting();
//
//    // Disconnects from a server (telling it so) if we are connected
//    void DisconnectFromServer();

////-----------------------------------------------------------------------------
//// Purpose: applies a command-line connect
////-----------------------------------------------------------------------------
//void CSpaceWarClient::ExecCommandLineConnect( const char *pchServerAddress, const char *pchLobbyID )
//{
//    if ( pchServerAddress )
//    {
//        int32 octet0 = 0, octet1 = 0, octet2 = 0, octet3 = 0;
//        int32 uPort = 0;
//        int nConverted = sscanf( pchServerAddress, "%d.%d.%d.%d:%d", &octet0, &octet1, &octet2, &octet3, &uPort );
//        if ( nConverted == 5 )
//        {
//            char rgchIPAddress[128];
//            sprintf_safe( rgchIPAddress, "%d.%d.%d.%d", octet0, octet1, octet2, octet3 );
//            uint32 unIPAddress = ( octet3 ) + ( octet2 << 8 ) + ( octet1 << 16 ) + ( octet0 << 24 );
//            InitiateServerConnection( unIPAddress, uPort );
//        }
//    }
//
//    // if +connect_lobby was used to specify a lobby to join, connect now
//    if ( pchLobbyID )
//    {
//        CSteamID steamIDLobby( (uint64)atoll( pchLobbyID ) );
//        if ( steamIDLobby.IsValid() )
//        {
//            // act just like we had selected it from the menu
//            LobbyBrowserMenuItem_t menuItem = { steamIDLobby, k_EClientJoiningLobby };
//            OnMenuSelection( menuItem );
//        }
//    }
//}

////-----------------------------------------------------------------------------
//// Purpose: Receive an authentication response from the server
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnReceiveServerAuthenticationResponse( bool bSuccess, uint32 uPlayerPosition )
//{
//    if ( !bSuccess )
//    {
//        SetConnectionFailureText( "Connection failure.\nMultiplayer authentication failed\n" );
//        SetGameState( k_EClientGameConnectionFailure );
//        DisconnectFromServer();
//    }
//    else
//    {
//        // Is this a duplicate message? If so ignore it...
//        if ( m_eConnectedStatus == k_EClientConnectedAndAuthenticated && m_uPlayerShipIndex == uPlayerPosition )
//            return;
//
//        m_uPlayerShipIndex = uPlayerPosition;
//        m_eConnectedStatus = k_EClientConnectedAndAuthenticated;
//
//        // set information so our friends can join the lobby
//        UpdateRichPresenceConnectionInfo();
//
//        // tell steam china duration control system that we are in a match and not to be interrupted
//        SteamUser()->BSetDurationControlOnlineState( k_EDurationControlOnlineState_OnlineHighPri );
//    }
//}
//
//void CSpaceWarClient::OnReceiveServerFullResponse()
//{
//    SetConnectionFailureText("Connection failure.\nServer is full\n");
//    SetGameState(k_EClientGameConnectionFailure);
//    DisconnectFromServer();
//}
//
//
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
//    if ( m_pP2PAuthedGame )
//    {
//        // has the player list changed?
//        if ( m_pServer )
//        {
//            // if i am the server owner i need to auth everyone who wants to play
//            // assume i am in slot 0, so start at slot 1
//            for( uint32 i=1; i < MAX_PLAYERS_PER_SERVER; ++i )
//            {
//                CSteamID steamIDNew( pUpdateData->GetPlayerSteamID(i) );
//                if ( steamIDNew == SteamUser()->GetSteamID() )
//                {
//                    OutputDebugString( "Server player slot 0 is not server owner.\n" );
//                }
//                else if ( steamIDNew != m_rgSteamIDPlayers[i] )
//                {
//                    if ( m_rgSteamIDPlayers[i].IsValid() )
//                    {
//                        m_pP2PAuthedGame->PlayerDisconnect( i );
//                    }
//                    if ( steamIDNew.IsValid() )
//                    {
//                        m_pP2PAuthedGame->RegisterPlayer( i, steamIDNew );
//                    }
//                }
//            }
//        }
//        else
//        {
//            // i am just a client, i need to auth the game owner ( slot 0 )
//            CSteamID steamIDNew( pUpdateData->GetPlayerSteamID( 0 ) );
//            if ( steamIDNew == SteamUser()->GetSteamID() )
//            {
//                OutputDebugString( "Server player slot 0 is not server owner.\n" );
//            }
//            else if ( steamIDNew != m_rgSteamIDPlayers[0] )
//            {
//                if ( m_rgSteamIDPlayers[0].IsValid() )
//                {
//                    OutputDebugString( "Server player slot 0 has disconnected - but thats the server owner.\n" );
//                    m_pP2PAuthedGame->PlayerDisconnect( 0 );
//                }
//                if ( steamIDNew.IsValid() )
//                {
//                    m_pP2PAuthedGame->StartAuthPlayer( 0, steamIDNew );
//                }
//            }
//        }
//    }
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

////-----------------------------------------------------------------------------
//// Purpose: Send data to the current server
////-----------------------------------------------------------------------------
//bool CSpaceWarClient::BSendServerData( const void *pData, uint32 nSizeOfData, int nSendFlags )
//{
//    EResult res = SteamNetworkingSockets()->SendMessageToConnection( m_hConnServer, pData, nSizeOfData, nSendFlags, nullptr );
//    switch (res)
//    {
//        case k_EResultOK:
//        case k_EResultIgnored:
//            break;
//
//        case k_EResultInvalidParam:
//            OutputDebugString("Failed sending data to server: Invalid connection handle, or the individual message is too big\n");
//            return false;
//        case k_EResultInvalidState:
//            OutputDebugString("Failed sending data to server: Connection is in an invalid state\n");
//            return false;
//        case k_EResultNoConnection:
//            OutputDebugString("Failed sending data to server: Connection has ended\n");
//            return false;
//        case k_EResultLimitExceeded:
//            OutputDebugString("Failed sending data to server: There was already too much data queued to be sent\n");
//            return false;
//        default:
//        {
//            char msg[256];
//            sprintf( msg, "SendMessageToConnection returned %d\n", res );
//            OutputDebugString( msg );
//            return false;
//        }
//    }
//    return true;
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Initiates a connection to a server
////-----------------------------------------------------------------------------
//void CSpaceWarClient::InitiateServerConnection( uint32 unServerAddress, const int32 nPort )
//{
//    if ( m_eGameState == k_EClientInLobby && m_steamIDLobby.IsValid() )
//    {
//        SteamMatchmaking()->LeaveLobby( m_steamIDLobby );
//    }
//
//    SetGameState( k_EClientGameConnecting );
//
//    // Update when we last retried the connection, as well as the last packet received time so we won't timeout too soon,
//    // and so we will retry at appropriate intervals if packets drop
//    m_ulLastNetworkDataReceivedTime = m_ulLastConnectionAttemptRetryTime = m_pGameEngine->GetGameTickCount();
//
//    // ping the server to find out what it's steamID is
//    m_unServerIP = unServerAddress;
//    m_usServerPort = (uint16)nPort;
//    m_GameServerPing.RetrieveSteamIDFromGameServer( this, m_unServerIP, m_usServerPort );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Initiates a connection to a server via P2P (NAT-traversing) connection
////-----------------------------------------------------------------------------
func initiateServerConnection(to serverSteamID: SteamID) {
    //    if ( m_eGameState == k_EClientInLobby && m_steamIDLobby.IsValid() )
    //    {
    //        SteamMatchmaking()->LeaveLobby( m_steamIDLobby );
    //    }
    //
    //    SetGameState( k_EClientGameConnecting );
    clientConnection.connect(steamID: serverSteamID)
    //    if ( m_pVoiceChat )
    //        m_pVoiceChat->m_hConnServer = m_hConnServer;
    //    if ( m_pP2PAuthedGame )
    //        m_pP2PAuthedGame->m_hConnServer = m_hConnServer;
}

////-----------------------------------------------------------------------------
//// Purpose: Handle the server telling us it is exiting
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnReceiveServerExiting()
//{
//    if ( m_pP2PAuthedGame )
//        m_pP2PAuthedGame->EndGame();
//
//#ifdef USE_GS_AUTH_API
//    if ( m_hAuthTicket != k_HAuthTicketInvalid )
//    {
//        SteamUser()->CancelAuthTicket( m_hAuthTicket );
//    }
//    m_hAuthTicket = k_HAuthTicketInvalid;
//#else
//    SteamUser()->AdvertiseGame( k_steamIDNil, 0, 0 );
//#endif
//
//    if ( m_eGameState != k_EClientGameActive )
//        return;
//    m_eConnectedStatus = k_EClientNotConnected;
//
//    SetConnectionFailureText( "Game server has exited." );
//    SetGameState( k_EClientGameConnectionFailure );
//}


// MARK: C++ Core Game State

//    // Were we the winner?
//    bool BLocalPlayerWonLastGame();

//    // Server we are connected to
//    CSpaceWarServer *m_pServer;
//
//    // Our ship position in the array below
//    uint32 m_uPlayerShipIndex;
//
//    // List of steamIDs for each player
//    CSteamID m_rgSteamIDPlayers[MAX_PLAYERS_PER_SERVER];
//
//    // Ships for players, doubles as a way to check for open slots (pointer is NULL meaning open)
//    CShip *m_rgpShips[MAX_PLAYERS_PER_SERVER];
//
//    // Player scores
//    uint32 m_rguPlayerScores[MAX_PLAYERS_PER_SERVER];
//
//    // Who just won the game? Should be set if we go into the k_EGameWinner state
//    uint32 m_uPlayerWhoWonGame;

////-----------------------------------------------------------------------------
//// Purpose: Did we win the last game?
////-----------------------------------------------------------------------------
//bool CSpaceWarClient::BLocalPlayerWonLastGame()
//{
//    if ( m_eGameState == k_EClientGameWinner )
//    {
//        if ( m_uPlayerWhoWonGame >= MAX_PLAYERS_PER_SERVER )
//        {
//            // ur
//            return false;
//        }
//
//        if ( m_rgpShips[m_uPlayerWhoWonGame] && m_rgpShips[m_uPlayerWhoWonGame]->BIsLocalPlayer() )
//        {
//            return true;
//        }
//        else
//        {
//            return false;
//        }
//    }
//    else
//    {
//        return false;
//    }
//}
}
