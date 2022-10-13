//
//  Lobby.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

// MARK: C++ Lobby Browser

/// Root of everything to do with lobbies and matchmaking.
///
/// Main flows:
/// 1) Create Lobby -> start server locally and join it
/// 2) Browse for existing lobby -> join it -> join server remotely
///
class Lobbies {
    private let steam: SteamAPI
    private let engine: Engine2D

    enum State {
        case idle
        case creatingLobby
        case inLobby
        case findLobby
        case joiningLobby
    }
    private(set) var state: MonitoredState<State>

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam
        self.state = MonitoredState(engine: engine, initial: .idle)
    }

    // MARK: Kick-off entrypoints

    func createLobby() {
        precondition(state.state == .idle)
        state.set(.creatingLobby)
    }

    func findLobby() {
        precondition(state.state == .idle)
        state.set(.findLobby)
    }

    // MARK: State machine

    func onStateChanged() {
        //    else if ( m_eGameState == k_EClientCreatingLobby )
        //    {
        //        // start creating the lobby
        //        if ( !m_SteamCallResultLobbyCreated.IsActive() )
        //        {
        //            // ask steam to create a lobby
        //            SteamAPICall_t hSteamAPICall = SteamMatchmaking()->CreateLobby( k_ELobbyTypePublic /* public lobby, anyone can find it */, 4 );
        //            // set the function to call when this completes
        //            m_SteamCallResultLobbyCreated.Set( hSteamAPICall, this, &CSpaceWarClient::OnLobbyCreated );
        //        }
        //        SteamFriends()->SetRichPresence( "status", "Creating a lobby" );
        //        pchSteamRichPresenceDisplay = "WaitingForMatch";
        //    }
        //    else if ( m_eGameState == k_EClientInLobby )
        //    {
        //        pchSteamRichPresenceDisplay = "WaitingForMatch";
        //    }
        //    else if ( m_eGameState == k_EClientFindLobby )
        //    {
        //        m_pLobbyBrowser->Refresh();
        //        SteamFriends()->SetRichPresence( "status", "Main menu: finding lobbies" );
        //        pchSteamRichPresenceDisplay = "WaitingForMatch";
        //    }

        //
        //    if ( pchSteamRichPresenceDisplay != NULL )
        //    {
        //        SteamFriends()->SetRichPresence( "steam_display", bDisplayScoreInRichPresence ? "#StatusWithScore" : "#StatusWithoutScore" );
        //        SteamFriends()->SetRichPresence( "gamestatus", pchSteamRichPresenceDisplay );
        //    }

        //void CSpaceWarClient::UpdateRichPresenceConnectionInfo()
    }

    /// Frame poll function.
    /// Called by `SpaceWarMain` when it thinks we're in a state of running/starting a game.
    /// Return what we want to do next.
    enum FrameRc {
        case lobby // stay in lobby screen
        case mainMenu // quit back to mainMenu
        case runGame(SteamID, Int? /*SpaceWarServer?*/) // connect to this server (maybe run it too)
    }

    func runFrame() -> FrameRc {
        precondition(state.state != .idle, "SpaceWarMain thinks we're busy but we're idle :-(")

        //    if ( m_eConnectedStatus != k_EClientNotConnected && m_pGameEngine->GetGameTickCount() - m_ulLastNetworkDataReceivedTime > MILLISECONDS_CONNECTION_TIMEOUT )
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
            //    case k_EClientCreatingLobby:
            //        // draw some text about creating lobby (may take a second or two)
            //        break;
            //
            //    case k_EClientInLobby:
            //        // display the lobby
            //        m_pLobby->RunFrame();
            //
            //        // see if we have a game server ready to play on
            //        if ( m_pServer && m_pServer->IsConnectedToSteam() )
            //        {
            //            // server is up; tell everyone else to connect
            //            SteamMatchmaking()->SetLobbyGameServer( m_steamIDLobby, 0, 0, m_pServer->GetSteamID() );
            //            // start connecting ourself via localhost (this will automatically leave the lobby)
            //            InitiateServerConnection( m_pServer->GetSteamID() );
            //        }
            //        break;
            //
            //    case k_EClientFindLobby:
            //        // display the list of lobbies
            //        m_pLobbyBrowser->RunFrame();
            //        break;
            //
            //    case k_EClientJoiningLobby:
            //        // Draw text telling the user a connection attempt is in progress
            //        DrawConnectionAttemptText();
            //
            //        // Check if we've waited too long and should time out the connection
            //        if ( m_pGameEngine->GetGameTickCount() - m_ulStateTransitionTime > MILLISECONDS_CONNECTION_TIMEOUT )
            //        {
            //            SetConnectionFailureText( "Timed out connecting to lobby." );
            //            SetGameState( k_EClientGameConnectionFailure );
            //        }
            //        break;
        default:
            break
        }

        return .mainMenu
    }
}


//// a game server as shown in the find servers menu
//struct ServerBrowserMenuData_t
//{
//    EClientGameState m_eStateToTransitionTo;
//    CSteamID m_steamIDGameServer;
//};
//
//// a lobby as shown in the find lobbies menu
//struct LobbyBrowserMenuItem_t
//{
//    CSteamID m_steamIDLobby;
//    EClientGameState m_eStateToTransitionTo;
//};
//
//// a user as shown in the lobby screen
//struct LobbyMenuItem_t
//{
//    enum ELobbyMenuItemCommand
//    {
//        k_ELobbyMenuItemUser,
//        k_ELobbyMenuItemStartGame,
//        k_ELobbyMenuItemToggleReadState,
//        k_ELobbyMenuItemLeaveLobby,
//        k_ELobbyMenuItemInviteToLobby
//    };
//
//    CSteamID m_steamIDUser;        // the user who this is in the lobby
//    ELobbyMenuItemCommand m_eCommand;
//    CSteamID m_steamIDLobby;    // set if k_ELobbyMenuItemInviteToLobby
//};

//    // Menu callback handler (handles server browser selections with extra data)
//    void OnMenuSelection( ServerBrowserMenuData_t selection )
//    {
//        if ( selection.m_eStateToTransitionTo == k_EClientGameConnecting )
//        {
//            InitiateServerConnection( selection.m_steamIDGameServer );
//        }
//        else
//        {
//            SetGameState( selection.m_eStateToTransitionTo );
//        }
//    }

//    void OnMenuSelection( LobbyBrowserMenuItem_t selection )
//    {
//        // start joining the lobby
//        if ( selection.m_eStateToTransitionTo == k_EClientJoiningLobby )
//        {
//            SteamAPICall_t hSteamAPICall = SteamMatchmaking()->JoinLobby( selection.m_steamIDLobby );
//            // set the function to call when this API completes
//            m_SteamCallResultLobbyEntered.Set( hSteamAPICall, this, &CSpaceWarClient::OnLobbyEntered );
//        }
//
//        SetGameState( selection.m_eStateToTransitionTo );
//    }

//    // simple class to marshal callbacks from pinging a game server
//    class CGameServerPing : public ISteamMatchmakingPingResponse
//    {
//    public:
//        CGameServerPing()
//        {
//            m_hGameServerQuery = HSERVERQUERY_INVALID;
//            m_pSpaceWarsClient = NULL;
//        }
//
//        void RetrieveSteamIDFromGameServer( CSpaceWarClient *pSpaceWarClient, uint32 unIP, uint16 unPort )
//        {
//            m_pSpaceWarsClient = pSpaceWarClient;
//            m_hGameServerQuery = SteamMatchmakingServers()->PingServer( unIP, unPort, this );
//        }
//
//        void CancelPing()
//        {
//            m_hGameServerQuery = HSERVERQUERY_INVALID;
//        }
//
//        // Server has responded successfully and has updated data
//        virtual void ServerResponded( gameserveritem_t &server )
//        {
//            if ( m_hGameServerQuery != HSERVERQUERY_INVALID && server.m_steamID.IsValid() )
//            {
//                m_pSpaceWarsClient->InitiateServerConnection( server.m_steamID );
//            }
//
//            m_hGameServerQuery = HSERVERQUERY_INVALID;
//        }
//
//        // Server failed to respond to the ping request
//        virtual void ServerFailedToRespond()
//        {
//            m_hGameServerQuery = HSERVERQUERY_INVALID;
//        }
//
//    private:
//        HServerQuery m_hGameServerQuery;    // we're ping a game server, so we can convert IP:Port to a steamID
//        CSpaceWarClient *m_pSpaceWarsClient;
//    };
//    CGameServerPing m_GameServerPing;

//    // lobby handling
//    // the name of the lobby we're connected to
//    CSteamID m_steamIDLobby;
//    // callback for when we're creating a new lobby
//    void OnLobbyCreated( LobbyCreated_t *pCallback, bool bIOFailure );
//    CCallResult<CSpaceWarClient, LobbyCreated_t> m_SteamCallResultLobbyCreated;
//
//    // callback for when we've joined a lobby
//    void OnLobbyEntered( LobbyEnter_t *pCallback, bool bIOFailure );
//    CCallResult<CSpaceWarClient, LobbyEnter_t> m_SteamCallResultLobbyEntered;
//
//    // callback for when the lobby game server has started
//    STEAM_CALLBACK( CSpaceWarClient, OnLobbyGameCreated, LobbyGameCreated_t );
//    STEAM_CALLBACK( CSpaceWarClient, OnAvatarImageLoaded, AvatarImageLoaded_t );

////-----------------------------------------------------------------------------
//// Purpose: Finishes up entering a lobby of our own creation
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnLobbyCreated( LobbyCreated_t *pCallback, bool bIOFailure )
//{
//    if ( m_eGameState != k_EClientCreatingLobby )
//        return;
//
//    // record which lobby we're in
//    if ( pCallback->m_eResult == k_EResultOK )
//    {
//        // success
//        m_steamIDLobby = pCallback->m_ulSteamIDLobby;
//        m_pLobby->SetLobbySteamID( m_steamIDLobby );
//
//        // set the name of the lobby if it's ours
//        char rgchLobbyName[256];
//        sprintf_safe( rgchLobbyName, "%s's lobby", SteamFriends()->GetPersonaName() );
//        SteamMatchmaking()->SetLobbyData( m_steamIDLobby, "name", rgchLobbyName );
//
//        // mark that we're in the lobby
//        SetGameState( k_EClientInLobby );
//    }
//    else
//    {
//        // failed, show error
//        SetConnectionFailureText( "Failed to create lobby (lost connection to Steam back-end servers." );
//        SetGameState( k_EClientGameConnectionFailure );
//    }
//}
//
////-----------------------------------------------------------------------------
//// Purpose: Finishes up entering a lobby
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnLobbyEntered( LobbyEnter_t *pCallback, bool bIOFailure )
//{
//    if ( m_eGameState != k_EClientJoiningLobby )
//        return;
//
//    if ( pCallback->m_EChatRoomEnterResponse != k_EChatRoomEnterResponseSuccess )
//    {
//        // failed, show error
//        SetConnectionFailureText( "Failed to enter lobby" );
//        SetGameState( k_EClientGameConnectionFailure );
//        return;
//    }
//
//    // success
//
//    // move forward the state
//    m_steamIDLobby = pCallback->m_ulSteamIDLobby;
//    m_pLobby->SetLobbySteamID( m_steamIDLobby );
//    SetGameState( k_EClientInLobby );
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Joins a game from a lobby
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnLobbyGameCreated( LobbyGameCreated_t *pCallback )
//{
//    if ( m_eGameState != k_EClientInLobby )
//        return;
//
//    // join the game server specified, via whichever method we can
//    if ( CSteamID( pCallback->m_ulSteamIDGameServer ).IsValid() )
//    {
//        InitiateServerConnection( CSteamID( pCallback->m_ulSteamIDGameServer ) );
//    }
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: a large avatar image has been loaded for us
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnAvatarImageLoaded( AvatarImageLoaded_t *pCallback )
//{
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: Handles menu actions in a lobby
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnMenuSelection( LobbyMenuItem_t selection )
//{
//    if ( selection.m_eCommand == LobbyMenuItem_t::k_ELobbyMenuItemLeaveLobby )
//    {
//        // leave the lobby
//        SteamMatchmaking()->LeaveLobby( m_steamIDLobby );
//        m_steamIDLobby = CSteamID();
//
//        // return to main menu
//        SetGameState( k_EClientGameMenu );
//    }
//    else if ( selection.m_eCommand == LobbyMenuItem_t::k_ELobbyMenuItemToggleReadState )
//    {
//        // update our state
//        bool bOldState = ( 1 == atoi( SteamMatchmaking()->GetLobbyMemberData( m_steamIDLobby, SteamUser()->GetSteamID(), "ready" ) ) );
//        bool bNewState = !bOldState;
//        // publish to everyone
//        SteamMatchmaking()->SetLobbyMemberData( m_steamIDLobby, "ready", bNewState ? "1" : "0" );
//    }
//    else if ( selection.m_eCommand == LobbyMenuItem_t::k_ELobbyMenuItemStartGame )
//    {
//        // make sure we're not already starting a server
//        if ( m_pServer )
//            return;
//
//        // broadcast to everyone in the lobby that the game is starting
//        SteamMatchmaking()->SetLobbyData( m_steamIDLobby, "game_starting", "1" );
//
//        // start a local game server
//        m_pServer = new CSpaceWarServer( m_pGameEngine );
//        // we'll have to wait until the game server connects to the Steam server back-end
//        // before telling all the lobby members to join (so that the NAT traversal code has a path to contact the game server)
//        OutputDebugString( "Game server being created; game will start soon.\n" );
//    }
//    else if ( selection.m_eCommand == LobbyMenuItem_t::k_ELobbyMenuItemInviteToLobby )
//    {
//        SteamFriends()->ActivateGameOverlayInviteDialog( selection.m_steamIDLobby );
//    }
//}
