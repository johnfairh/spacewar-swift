//
//  Matchmaking.swift
//  SpaceWar
//

// MARK: C++ Server/Lobby Browser

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
