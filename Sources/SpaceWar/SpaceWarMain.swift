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

extension Engine2D.TickCount {
    func isMoreThan(_ duration: Engine2D.TickCount, since: Engine2D.TickCount) -> Bool {
        self - since > duration
    }

    func isLessThan(_ duration: Engine2D.TickCount, since: Engine2D.TickCount) -> Bool {
        self - since < duration
    }
}

/// Gadget to wrap up the 'state' pattern that gets split three ways in this port.
///
/// Record time of state change
/// Provide call to execute code first time made in new state
/// Provide setter to nop if already there and execute code if not
struct MonitoredState<ActualState: Equatable> {
    let engine: Engine2D

    init(engine: Engine2D, initial: ActualState) {
        self.engine = engine
        self.state = initial
        self.transitioned = false
        self.transitionTime = 0
    }

    private(set) var state: ActualState

    mutating func set(_ newState: ActualState, call: () -> Void = {}) {
        guard newState != state else {
            return
        }
        state = newState
        transitioned = true
        transitionTime = engine.gameTickCount
        call()
    }

    private(set) var transitioned: Bool
    private(set) var transitionTime: Engine2D.TickCount

    mutating func onTransition(call: () -> Void) {
        if transitioned {
            transitioned = false
            call()
        }
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
    private(set) var gameState: MonitoredState<MainGameState>
    private var cancelInput: Debounced
    private var infrequent: Debounced

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        // On PC/OSX we always know the user has a SteamID and is logged in already.
        precondition(steam.user.loggedOn())
        localUserSteamID = steam.user.getSteamID()

        gameState = MonitoredState(engine: engine, initial: .gameMenu)
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

        // Connect to general Steam notifications

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

        // Command-line server-connect instructions

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

    private var handledForceQuit = false
    func forceQuit(reason: String) {
        guard !handledForceQuit else {
            return
        }
        handledForceQuit = true
        OutputDebugString("Forced to quit: \(reason)")
        SpaceWarApp.quit()
    }

    // MARK: State machine

    /// Transition game state
    func setGameState(_ state: MainGameState) {
        gameState.set(state) {
            //    // update any rich presence state
            //    XXX UpdateRichPresenceConnectionInfo();
        }
    }

    func onGameStateChanged() {
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

        case .retrySteamConnection, .linkSteamAccount, .autoCreateAccount:
            preconditionFailure("Unexpected PS3-specific state")

//        case .gameMenu:
//            // XXX MainMenu m_pMainMenu->RunFrame();
//            // Make sure the Steam Controller is in the correct mode.
//            // XXX SteamInput m_pGameEngine->SetSteamControllerActionSet( eControllerActionSet_MenuControls );
//            break;

        case .startServer:
            gameClient.startServer()
            setGameState(.runningGame)

        case .runningGame:
            if !gameClient.runFrame() {
                setGameState(.gameMenu)
            }

        case .joinLobby:
            lobbies.findLobby()
            setGameState(.doingLobby)
        case .createLobby:
            lobbies.createLobby()
            setGameState(.doingLobby)

        case .doingLobby:
            switch lobbies.runFrame() {
            case .mainMenu:
                setGameState(.gameMenu)
            case .lobby:
                break
            case .runGame(let steamID, let server):
                gameClient.connectFromLobby(steamID: steamID, server: server)
                setGameState(.runningGame)
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

            //    case k_EClientMinidump:
            //#ifdef _WIN32
            //        RaiseException( EXCEPTION_NONCONTINUABLE_EXCEPTION,
            //            EXCEPTION_NONCONTINUABLE,
            //            0, NULL );
            //#endif
            //        SetGameState( k_EClientGameMenu );
            //        break;

            // XXX not sure about this yet, steam china out-of-the-blue
            //     and game quit menu.
            // Think nuke it, don't need a state, just quit
            //    case k_EClientGameExiting:
            //        DisconnectFromServer();
            //        m_pGameEngine->Shutdown();
            //        return;

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
            OutputDebugString("Unhandled game client state \(gameState)")
        }

        if engine.isKeyDown(.printable("Q")) {
            SpaceWarApp.quit()
        }
    }

    func runOccasionally() {
        print("occasion")
    }

    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
        gameClient.receiveNetworkData()
    }
}

/// Helper to debounce events eg. to avoid one 'esc' press jumping through layers of menus
struct Debounced {
    let sample: () -> Bool
    let debounce: Engine2D.TickCount

    private(set) var lastPress: Engine2D.TickCount

    /// Wrap a predicate so it returns `true` only once every `debounce` milliseconds
    init(debounce: Engine2D.TickCount, sample: @escaping () -> Bool) {
        self.sample = sample
        self.debounce = debounce
        self.lastPress = 0
    }

    mutating func test(now: Engine2D.TickCount) -> Bool {
        guard sample(), now.isMoreThan(debounce, since: lastPress) else {
            return false
        }
        lastPress = now
        return true
    }
}
