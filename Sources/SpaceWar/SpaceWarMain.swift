//
//  SpaceWarMain.swift
//  SpaceWar
//

import Steamworks
import MetalEngine
import Foundation

/// Top-level game control type holding ref to the Steam client and everything else.
///
/// Corresponds to the non-core-game parts of SpaceWarClient, attempting to split
/// up and make sense of that monster.
///
/// SpaceWarApp holds the only reference to this and clears it when told to quit.
///
/// The entire architecture of this program is cruft and accretion - knowingly cargo-culting it.
/// Though I have modularized slightly rather than having one massive state enum.
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
    private let lobbies: Lobbies
    private let starField: StarField

    /// Overall game state
    enum State {
        case connectingToSteam
        case gameMenu
        case startServer
        case findLANServers
        case findInternetServers
        case createLobby
        case joinLobby
        case gameInstructions
        case statsAchievements
        case leaderboards
        case friendsList
        case clanChatRoom
        case remotePlay
        case remoteStorage
        case webCallback
        case music
        case workshop
        case htmlSurface
        case inGameStore
        case overlayAPI
        case gameExiting
    }
    private(set) var gameState: MonitoredState<State>
    private var cancelInput: Debounced
    private var infrequent: Debounced

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        // On PC/OSX we always know the user has a SteamID and is logged in already.
        precondition(steam.user.loggedOn())
        localUserSteamID = steam.user.getSteamID()

        gameState = MonitoredState(tickSource: engine, initial: .gameMenu)
        cancelInput = Debounced(debounce: 250) {
            engine.isKeyDown(.escape)
            /* XXX SteamInput ||
             m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_PauseMenu ) ||
             m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_MenuCancel ) ) */
        }
        // Gadget to fire every second
        infrequent = Debounced(debounce: 1000) { true }

        // The game part of spacewarclient
        gameClient = SpaceWarClient(engine: engine, steam: steam)
        // The lobby part of spacewarclient
        lobbies = Lobbies(engine: engine, steam: steam)

        // Initialize starfield - common background almost always drawn
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

        // Initialize engine
        engine.setBackgroundColor(.rgb(0, 0, 0))

        // Initialize networking
        steam.networkingUtils.initRelayNetworkAccess()

        Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { [weak self] _ in
            self?.receiveNetworkData()
        }

        initSteamNotifications()
        initCommandLine()
    }

    // MARK: General Steam Infrastructure Interlocks

    /// Connect to general Steam notifications, roughly all lifecycle-related
    private func initSteamNotifications() {
        steam.onIPCFailure { [weak self] msg in
            // Some awful O/S or library error
            self?.forceQuit(reason: "Steam IPC Failure (\(msg.failureType))")
        }

        steam.onSteamShutdown { [weak self] _ in
            // Steam shutdown request due to a user in a second concurrent session
            // requesting to play this game
            self?.forceQuit(reason: "Steam Shutdown")
        }

        steam.onSteamServersDisconnected { [weak self] _ in
            // Notification that we've been disconnected from Steam
            guard let self else {
                return
            }
            self.setGameState(.connectingToSteam)
            OutputDebugString("Got SteamServersDisconnected_t")
        }

        steam.onSteamServersConnected { [weak self] _ in
            // Notification that we are reconnected to Steam
            if let self, self.steam.user.loggedOn() {
                self.setGameState(.gameMenu)
            } else {
                OutputDebugString("Got SteamServersConnected, but not logged on?")
            }
        }

        steam.onDurationControl { [weak self] msg in
            // Notification that a Steam China duration control event has happened
            self?.onDurationControl(msg: msg)
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

    /// Steam China duration control: called manually on occasion, can be async notification too
    func onDurationControl(msg: DurationControl) {
        if msg.csecsRemaining > 0 && msg.csecsRemaining < 30 {
            // Player doesn't have much playtime left, warn them
            OutputDebugString("Duration control: Playtime remaining is short - exit soon!")
        }

        func message(_ progress: DurationControlProgress) -> String? {
            switch progress {
            case .exitSoon3h: return "3h playtime since last 5h break"
            case .exitSoon5h: return "5h playtime today"
            case .exitSoonNight: return "10PM-8AM"
            default: return nil
            }
        }

        guard let exitMsg = message(msg.progress) else {
            return
        }
        OutputDebugString("Duration control termination: \(exitMsg) (remaining time: \(msg.csecsRemaining))")

        // perform a clean exit
        setGameState(.gameExiting)
    }

    /// Command-line server-connect instructions, from various places
    private func initCommandLine() {
        if let cmdLineParams = CmdLineParams() ?? CmdLineParams(steam: steam) {
            gameClient.execCommandLineConnect(params: cmdLineParams)
        }

        steam.onGameRichPresenceJoinRequested { [weak self] msg in
            // Steam is asking us to join a game, based on the user selecting
            // 'join game' on a friend in their friends list
            OutputDebugString("RichPresenceJoinRequested: \(msg.connect)")
            if let self, let params = CmdLineParams(launchString: msg.connect) {
                self.gameClient.execCommandLineConnect(params: params)
            }
        }

        steam.onNewUrlLaunchParameters { [weak self] msg in
            // a Steam URL to launch this app was executed while the game is
            // already running, eg steam://run/480//+connect%20127.0.0.1
            if let self, let params = CmdLineParams(steam: self.steam) {
                self.gameClient.execCommandLineConnect(params: params)
            }
        }
    }

    /// Called from frame loop, but once every second or so instead of every frame
    func runOccasionally() {
        // Update duration control
        if steam.utils.isSteamChinaLauncher() {
            steam.user.getDurationControl() { [weak self] msg in
                if let msg, let self {
                    self.onDurationControl(msg: msg)
                }
            }
        }

        //    XXX stats // Service stats and achievements - infrequently except during game when it ALSO gets called in the per-frame GameActive bit
        //    m_pStatsAndAchievements->RunFrame();
    }

    // MARK: State machine

    /// Transition game state
    func setGameState(_ state: State) {
        gameState.set(state) {
            // XXX is this all really gone?
        }
    }

    /// Called in the first `RunFrame()` after the state is changed.  Old state is NOT available.
    func onGameStateChanged() {
        switch gameState.state {
        case .gameMenu:
            //        // we've switched out to the main menu
            //
            //        // Tell the server we have left if we are connected
            //        DisconnectFromServer();
            //
            //        // shut down any server we were running
            //        if ( m_pServer )
            //        {
            //            delete m_pServer;
            //            m_pServer = NULL;
            //        }
            //
            //        // Refresh inventory
            //        SpaceWarLocalInventory()->RefreshFromServer();
            break
        case .startServer:
            gameClient.startServer()
            // SpaceWarClient takes over now
        case .findLANServers:
            //        m_pServerBrowser->RefreshLANServers();
            break
        case .findInternetServers:
            //        // If we are just opening the find servers screen, then start a refresh
            //        m_pServerBrowser->RefreshInternetServers();
            break
        case .createLobby:
            lobbies.createLobby()
            // Lobbies takes over now
        case .joinLobby:
            lobbies.findLobby()
            // Lobbies takes over now
        case .leaderboards:
            //        // we've switched to the leaderboard menu
            //        m_pLeaderboards->Show();
            break
        case .friendsList:
            //        // we've switched to the friends list menu
            //        m_pFriendsList->Show();
            break
        case .clanChatRoom:
            //        // we've switched to the leaderboard menu
            //        m_pClanChatRoom->Show();
            break
        case .remotePlay:
            //        // we've switched to the remote play menu
            //        m_pRemotePlayList->Show();
            break
        case .remoteStorage:
            //        // we've switched to the remote storage menu
            //        m_pRemoteStorage->Show();
            break
        case .music:
            //        // we've switched to the music player menu
            //        m_pMusicPlayer->Show();
            break
        case .htmlSurface:
            //        // we've switched to the html page
            //        m_pHTMLSurface->Show();
            break
        case .inGameStore:
            //        // we've switched to the item store
            //        m_pItemStore->Show();
            break
        case .overlayAPI:
            //        // we've switched to the item store
            //        m_pOverlayExamples->Show();
            break
        case .gameExiting, .gameInstructions, .statsAchievements, .connectingToSteam, .webCallback, .workshop:
            // Nothing to do on entry to these states
            break
        }

        steam.friends.setRichPresence(status: gameState.state.richPresenceStatus)
        steam.friends.setRichPresence(gameStatus: gameState.state.richPresenceGameStatus)
        steam.friends.setRichPresence(playerGroup: nil)
        steam.friends.setRichPresence(connectedTo: .nothing)
    }

    /// Main frame function, updates the state of the world and performs rendering
    func runFrame() {
        // Get any new data off the network to begin with
        receiveNetworkData()

        // Check if escape has been pressed, we'll use that info in a couple places below
        let escapedPressed = cancelInput.test(now: engine.gameTickCount)

        // Run Steam client callbacks
        steam.runCallbacks()

        // Do work that runs infrequently. we do this every second
        if infrequent.test(now: engine.gameTickCount) {
            runOccasionally()
        }

        // if we just transitioned state, perform on change handlers
        gameState.onTransition {
            onGameStateChanged()
        }

        // factor out starfield rendering - do unless we're in web-page mode
        if gameState.state != .htmlSurface {
            starField.render()
        }

        // Update state for everything
        switch gameState.state {
        case .connectingToSteam:
            // Make sure the Steam Controller is in the correct mode.
            // XXX SteamInput       m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_MenuControls );
            break;

//        case .gameMenu:
//            // XXX MainMenu m_pMainMenu->RunFrame();
//            // Make sure the Steam Controller is in the correct mode.
//            // XXX SteamInput m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_MenuControls );
//            break;

        case .startServer:
            switch gameClient.runFrame() {
            case .mainMenu:
                setGameState(.gameMenu)
            case .quit:
                setGameState(.gameExiting)
            case .game:
                break
            }

        case .joinLobby, .createLobby:
            switch lobbies.runFrame() {
            case .mainMenu:
                setGameState(.gameMenu)
            case .lobby:
                break
            case .runGame(let steamID, let server):
                gameClient.connectFromLobby(steamID: steamID, server: server)
                setGameState(.startServer)
            }

    //    case k_EClientFindInternetServers:
    //    case k_EClientFindLANServers:
    //        m_pServerBrowser->RunFrame();
    //        break;


            //    case k_EClientGameInstructions:
            //        DrawInstructions();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;

            //    case k_EClientWorkshop:
            //        DrawWorkshopItems();
            //
            //        if (bEscapePressed)
            //            SetGameState(k_EClientGameMenu);
            //        break;

            //    case k_EClientStatsAchievements:
            //        m_pStatsAndAchievements->Render();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        if (m_pGameEngine->BIsKeyDown( 0x31 ) )
            //        {
            //            SpaceWarLocalInventory()->DoExchange();
            //        }
            //        else if ( m_pGameEngine->BIsKeyDown( 0x32 ) )
            //        {
            //            SpaceWarLocalInventory()->ModifyItemProperties();
            //        }
            //        break;

            //    case k_EClientLeaderboards:
            //        m_pLeaderboards->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;

            //    case k_EClientFriendsList:
            //        m_pFriendsList->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;

            //    case k_EClientClanChatRoom:
            //        m_pClanChatRoom->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;

            //    case k_EClientRemotePlay:
            //        m_pRemotePlayList->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;

            //    case k_EClientRemoteStorage:
            //        m_pRemoteStorage->Render();
            //        break;

            //    case k_EClientHTMLSurface:
            //        m_pHTMLSurface->RunFrame();
            //        m_pHTMLSurface->Render();
            //        break;

        case .gameExiting:
            gameClient.disconnectFromServer()
            forceQuit(reason: "Requested quit to desktop")

            //    case k_EClientWebCallback:
            //        if ( !m_bSentWebOpen )
            //        {
            //            m_bSentWebOpen = true;
            //#ifndef _PS3
            //            char szCurDir[MAX_PATH];
            //            if ( !_getcwd( szCurDir, sizeof(szCurDir) ) )
            //            {
            //                strcpy( szCurDir, "." );
            //            }
            //            char szURL[MAX_PATH];
            //            sprintf_safe( szURL, "file:///%s/test.html", szCurDir );
            //            // load the test html page, it just has a steam://gamewebcallback link in it
            //            SteamFriends()->ActivateGameOverlayToWebPage( szURL );
            //            SetGameState( k_EClientGameMenu );
            //#endif
            //        }
            //        break;

            //    case k_EClientMusic:
            //        m_pMusicPlayer->RunFrame();
            //
            //        if ( bEscapePressed )
            //        {
            //            SetGameState( k_EClientGameMenu );
            //        }
            //        break;

            //    case k_EClientInGameStore:
            //        m_pItemStore->RunFrame();
            //
            //        if (bEscapePressed)
            //            SetGameState(k_EClientGameMenu);
            //        break;

            //    case k_EClientOverlayAPI:
            //        m_pOverlayExamples->RunFrame();
            //
            //        if ( bEscapePressed )
            //            SetGameState( k_EClientGameMenu );
            //        break;
        default:
            OutputDebugString("Unhandled game client state \(gameState.state)")
        }

        if engine.isKeyDown(.printable("Q")) {
            setGameState(.gameExiting)
        }
    }

    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
        gameClient.receiveNetworkData()
    }
}
