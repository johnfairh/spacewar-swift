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
@MainActor
final class SpaceWarMain {
    private let engine: Engine2D
    private let steam: SteamAPI
    private let controller: Controller

    // Public useful cached stuff
    let localUserSteamID: SteamID

    var localPlayerName: String {
        steam.friends.getFriendPersonaName(friend: localUserSteamID)
    }

    // Components
    private let gameClient: SpaceWarClient
    private let lobbies: Lobbies
    private let starField: StarField
    private let mainMenu: MainMenu
    let inventory: SpaceWarLocalInventory
    private let statsAndAchievements: StatsAndAchievements

    /// Overall game state
    enum State: Equatable {
        case connectingToSteam
        case mainMenu
        case menuItem(MainMenuItem)
    }
    private(set) var gameState: MonitoredState<State>
    private var cancelInput: Debounced
    private var infrequent: Debounced
    private var networkRcvTask: Task<Void, Never>?

    init(engine: Engine2D, steam: SteamAPI, controller: Controller) {
        self.engine = engine
        self.steam = steam
        self.controller = controller

        // On PC/OSX we always know the user has a SteamID and is logged in already.
        precondition(steam.user.loggedOn())
        localUserSteamID = steam.user.getSteamID()

        gameState = MonitoredState(tickSource: engine, initial: .mainMenu, name: "Main")
        cancelInput = Debounced(debounce: 250) {
            engine.isKeyDown(.escape) ||
                controller.isActionActive(.pauseMenu) ||
                controller.isActionActive(.menuCancel)
        }
        // Gadget to fire every second
        infrequent = Debounced(debounce: 1000) { true }

        let stats = StatsAndAchievements(steam: steam, engine: engine, controller: controller)

        // The game part of spacewarclient
        gameClient = SpaceWarClient(engine: engine, controller: controller, steam: steam, stats: stats)
        // The lobby part of spacewarclient
        lobbies = Lobbies(engine: engine, steam: steam)

        // Initialize starfield - common background almost always drawn
        starField = StarField(engine: engine)

        // Initialize main menu
        mainMenu = MainMenu(engine: engine, controller: controller)

        inventory = SpaceWarLocalInventory(steam: steam)
        
        //    // All the non-game screens
        //    m_pServerBrowser = new CServerBrowser( m_pGameEngine );
        //    m_pLobbyBrowser = new CLobbyBrowser( m_pGameEngine );
        //    m_pLobby = new CLobby( m_pGameEngine );
        statsAndAchievements = stats
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
        if !FAKE_NET_USE {
            steam.networkingUtils.initRelayNetworkAccess()
        }

        networkRcvTask = Task { [weak self] in
            MainActor.assertIsolated() // does isolation inheritance work?
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                self?.receiveNetworkData()
            }
            OutputDebugString("NetworkRcvTask exitting")
        }

        initSteamNotifications()
        initCommandLine()
    }

    deinit {
        networkRcvTask?.cancel()
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
            self.gameState.set(.connectingToSteam)
            OutputDebugString("Got SteamServersDisconnected_t")
        }

        steam.onSteamServersConnected { [weak self] _ in
            // Notification that we are reconnected to Steam
            if let self, self.steam.user.loggedOn() {
                self.gameState.set(.mainMenu)
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
        gameState.set(.menuItem(.gameExiting))
    }

    /// Command-line server-connect instructions, from various places
    private func initCommandLine() {
        if let cmdLineParams = CmdLineParams() ?? CmdLineParams(steam: steam) {
            execCommandLineConnect(params: cmdLineParams)
        }

        steam.onGameRichPresenceJoinRequested { [weak self] msg in
            // Steam is asking us to join a game, based on the user selecting
            // 'join game' on a friend in their friends list
            OutputDebugString("RichPresenceJoinRequested: \(msg.connect)")
            if let self, let params = CmdLineParams(launchString: msg.connect) {
                self.execCommandLineConnect(params: params)
            }
        }

        steam.onNewUrlLaunchParameters { [weak self] msg in
            // a Steam URL to launch this app was executed while the game is
            // already running, eg steam://run/480//+connect%20127.0.0.1
            if let self, let params = CmdLineParams(steam: self.steam) {
                self.execCommandLineConnect(params: params)
            }
        }
    }

    /// This needs to be a lot smarter to avoid colliding badly with what is currently going on
    /// - check params are sane, go away if not
    /// - check main state: if we're not in lobby/gameclient then should be ok to just go there
    /// - otherwise have to call an API in lobby/gameclient passing in the cmdlineparams, to
    ///   let the l/gc gracefully clean and quit, passing the cmdlineparams back to us
    ///     - and then we can go back to step (2) and go to the new place...
    ///
    func execCommandLineConnect(params: CmdLineParams) {
        print("ExecCommandLineConnect: \(params)")
    }

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

        // Service stats and achievements - infrequently except during game when it
        // ALSO gets called in the per-frame GameActive bit
        statsAndAchievements.runFrame()
    }

    // MARK: State machine

    /// Called in the first `RunFrame()` after the state is changed.  Old state is NOT available.
    func onGameStateChanged() {
        switch gameState.state {
        case .mainMenu:
            mainMenu.resetSelection()
            // Refresh inventory
            inventory.refreshFromServer()
        case .menuItem(.startServer):
            gameClient.connectToLocalServer()
            // SpaceWarClient takes over now
        case .menuItem(.findLANServers):
            //        m_pServerBrowser->RefreshLANServers();
            break
        case .menuItem(.findInternetServers):
            //        // If we are just opening the find servers screen, then start a refresh
            //        m_pServerBrowser->RefreshInternetServers();
            break
        case .menuItem(.createLobby):
            lobbies.createLobby()
            // Lobbies takes over now
        case .menuItem(.findLobby):
            lobbies.findLobby()
            // Lobbies takes over now
        case .menuItem(.leaderboards):
            //        // we've switched to the leaderboard menu
            //        m_pLeaderboards->Show();
            break
        case .menuItem(.friendsList):
            //        // we've switched to the friends list menu
            //        m_pFriendsList->Show();
            break
        case .menuItem(.clanChatRoom):
            //        // we've switched to the leaderboard menu
            //        m_pClanChatRoom->Show();
            break
        case .menuItem(.remotePlay):
            //        // we've switched to the remote play menu
            //        m_pRemotePlayList->Show();
            break
        case .menuItem(.remoteStorage):
            //        // we've switched to the remote storage menu
            //        m_pRemoteStorage->Show();
            break
        case .menuItem(.music):
            //        // we've switched to the music player menu
            //        m_pMusicPlayer->Show();
            break
        case .menuItem(.htmlSurface):
            //        // we've switched to the html page
            //        m_pHTMLSurface->Show();
            break
        case .menuItem(.inGameStore):
            //        // we've switched to the item store
            //        m_pItemStore->Show();
            break
        case .menuItem(.overlayAPI):
            //        // we've switched to the item store
            //        m_pOverlayExamples->Show();
            break
        case .menuItem(.gameExiting), .menuItem(.gameInstructions), .menuItem(.statsAchievements), .connectingToSteam, .menuItem(.webCallback), .menuItem(.workshop):
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
        let escapePressed = cancelInput.test(now: engine.gameTickCount)

        // Run Steam client callbacks
        steam.runCallbacks()

        // Update controller events
        controller.runFrame()

        // Do work that runs infrequently. we do this every second
        if infrequent.test(now: engine.gameTickCount) {
            runOccasionally()
        }

        // if we just transitioned state, perform on change handlers
        gameState.onTransition {
            onGameStateChanged()
        }

        // factor out starfield rendering - do unless we're in web-page mode
        if gameState.state != .menuItem(.htmlSurface) {
            starField.render()
        }

        // Update state for everything
        switch gameState.state {
        case .connectingToSteam:
            // Make sure the Steam Controller is in the correct mode.
            controller.setActionSet(.menuControls)

        case .mainMenu:
            // Make sure the Steam Controller is in the correct mode.
            controller.setActionSet(.menuControls)
            mainMenu.runFrame()
            if let newState = mainMenu.selectedMenuItem {
                OutputDebugString("Main menu selection: \(newState)")
                gameState.set(.menuItem(newState))
            }

        case .menuItem(.startServer):
            switch gameClient.runFrame(escapePressed: escapePressed) {
            case .mainMenu:
                gameState.set(.mainMenu)
            case .quit:
                gameState.set(.menuItem(.gameExiting))
            case .game:
                break
            }

        case .menuItem(.findLobby), .menuItem(.createLobby):
            switch lobbies.runFrame() {
            case .mainMenu:
                gameState.set(.mainMenu)
            case .lobby:
                break
            case .remoteGame(let steamID):
                gameClient.connectTo(gameServerSteamID: steamID)
                gameState.set(.menuItem(.startServer))
            case .localGame(let server):
                gameClient.connectToLocalServer(server)
                gameState.set(.menuItem(.startServer))
            }

    //    case k_EClientFindInternetServers:
    //    case k_EClientFindLANServers:
    //        m_pServerBrowser->RunFrame();
    //        break;


        case .menuItem(.gameInstructions):
            gameClient.drawInstructions()
            if escapePressed {
                gameState.set(.mainMenu)
            }

            //    case k_EClientWorkshop:
            //        DrawWorkshopItems();
            //
            //        if (bEscapePressed)
            //            SetGameState(k_EClientGameMenu);
            //        break;

        case .menuItem(.statsAchievements):
            statsAndAchievements.render()

            if escapePressed {
                gameState.set(.mainMenu)
            }
            if engine.isKeyDown(.printable("1")) {
                inventory.doExchange()
            } else if engine.isKeyDown(.printable("2")) {
                inventory.modifyItemProperties()
            }
            break

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

        case .menuItem(.gameExiting):
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
            // OutputDebugString("Unhandled game client state \(gameState.state)")
            if escapePressed {
                gameState.set(.mainMenu)
            }
        }
    }

    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
        gameClient.receiveNetworkData()
    }
}

extension SpaceWarMain.State: CustomStringConvertible {
    var description: String {
        switch self {
        case .connectingToSteam: return "connectingToSteam"
        case .mainMenu: return "mainMenu"
        case .menuItem(let item): return "menuItem(\(item))"
        }
    }
}
