//
//  SpaceWarMain.swift
//  SpaceWar
//

import Steamworks
import MetalEngine
import Foundation

extension Engine2D {
    var gameTickCount: TickCount {
        frameTimestamp
    }
}

/// Top-level game control type holding ref to the Steam client and everything else.
///
/// Corresponds to the non-core-game parts of SpaceWarClient, attempting to split
/// up and make sense of that monster.
///
/// SpaceWarApp holds the only reference to this and clears it when told to quit.
///
/// The entire architecture of this program is cruft and accretion - knowingly cargo-culting it.
///
/// No PS3 accommodations.
final class SpaceWarMain {
    private let steam: SteamAPI
    private let engine: Engine2D

    // Public useful cached stuff
    let localUserSteamID: SteamID

    var localPlayerName: String {
        steam.friends.getFriendPersonaName(friend: localUserSteamID)
    }

    // Components
    private let gameClient: SpaceWarClient
    private let starField: StarField

    /// Overall game state - includes several states to do with actually running the game, that are owned
    /// by ``SpaceWarClient``, and states for each of the other demo/utility modes we can be in.
    private(set) var gameState: ClientGameState
    private(set) var stateTransitionTime: Engine2D.TickCount
    private var transitionedGameState: Bool

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        // On PC/OSX we always know the user has a SteamID and is logged in already.
        precondition(steam.user.loggedOn())
        localUserSteamID = steam.user.getSteamID()

        gameState = .gameMenu // main menu
        stateTransitionTime = engine.gameTickCount
        transitionedGameState = true

        // The game part of spacewarclient
        gameClient = SpaceWarClient(engine: engine, steam: steam)

        // Initialize starfield - common background almost always there
        starField = StarField(engine: engine)

        //    // Initialize main menu
        //    m_pMainMenu = new CMainMenu( pGameEngine );

        //    // All the non-game screens
        //    m_pServerBrowser = new CServerBrowser( m_pGameEngine );
        //    m_pLobbyBrowser = new CLobbyBrowser( m_pGameEngine );
        //    m_pLobby = new CLobby( m_pGameEngine );
        //    m_pStatsAndAchievements = new CStatsAndAchievements( pGameEngine );
        //    m_pLeaderboards = new CLeaderboards( pGameEngine );
        //    m_pFriendsList = new CFriendsList( pGameEngine );
        //    m_pMusicPlayer = new CMusicPlayer( pGameEngine );
        //    m_pClanChatRoom = new CClanChatRoom( pGameEngine );
        //    m_pRemotePlayList = new CRemotePlayList( pGameEngine );
        //    m_pRemoteStorage = new CRemoteStorage( pGameEngine );
        //    m_pHTMLSurface = new CHTMLSurface(pGameEngine);
        //    m_pItemStore = new CItemStore( pGameEngine );
        //    m_pItemStore->LoadItemsWithPrices();
        //    m_pOverlayExamples = new COverlayExamples( pGameEngine );

        // Initialize networking

        steam.networkingUtils.initRelayNetworkAccess()

        Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { [weak self] _ in
            self?.receiveNetworkData()
        }

        // Connect to general Steam notifications

        steam.onIPCFailure { [weak self] msg in
            self?.forceQuit(reason: "Steam IPC Failure (\(msg.failureType))")
        }

        // Steam shutdown request due to a user in a second concurrent session
        // requesting to play this game
        steam.onSteamShutdown { [weak self] _ in
            self?.forceQuit(reason: "Steam Shutdown")
        }
    }

    private var handledForceQuit = false
    func forceQuit(reason: String) {
        guard !handledForceQuit else {
            return
        }
        handledForceQuit = true
        OutputDebugString("Forced to quit: \(reason)")
        SpaceWarApp.quit()
    }

    func execCommandLineConnect(params: CmdLineParams) {
    }

    func retrieveEncryptedAppTicket() {
    }

    func runFrame() {
        receiveNetworkData()
        steam.runCallbacks()
        starField.render()

        if engine.isKeyDown(.printable("Q")) {
            SpaceWarApp.quit()
        }
    }

    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
    }
}

//    STEAM_CALLBACK( CSpaceWarClient, OnGameJoinRequested, GameRichPresenceJoinRequested_t );
//    STEAM_CALLBACK( CSpaceWarClient, OnNewUrlLaunchParameters, NewUrlLaunchParameters_t );


////-----------------------------------------------------------------------------
//// Purpose: Steam is asking us to join a game, based on the user selecting
////            'join game' on a friend in their friends list
////            the string comes from the "connect" field set in the friends' rich presence
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnGameJoinRequested( GameRichPresenceJoinRequested_t *pCallback )
//{
//    // parse out the connect
//    const char *pchServerAddress, *pchLobbyID;
//
//    if ( ParseCommandLine( pCallback->m_rgchConnect, &pchServerAddress, &pchLobbyID ) )
//    {
//        // exec
//        ExecCommandLineConnect( pchServerAddress, pchLobbyID );
//    }
//}
//
//
////-----------------------------------------------------------------------------
//// Purpose: a Steam URL to launch this app was executed while the game is already running, eg steam://run/480//+connect%20127.0.0.1
////          Anybody can build random Steam URLs    and these extra parameters must be carefully parsed to avoid unintended side-effects
////-----------------------------------------------------------------------------
//void CSpaceWarClient::OnNewUrlLaunchParameters( NewUrlLaunchParameters_t *pCallback )
//{
//    const char *pchServerAddress, *pchLobbyID;
//    char szCommandLine[1024] = {};
//
//    if ( SteamApps()->GetLaunchCommandLine( szCommandLine, sizeof(szCommandLine) ) > 0 )
//    {
//        if ( ParseCommandLine( szCommandLine, &pchServerAddress, &pchLobbyID ) )
//        {
//            // exec
//            ExecCommandLineConnect( pchServerAddress, pchLobbyID );
//        }
//    }
//}
//
//
