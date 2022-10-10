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
    private var cancelInput: Debounced
    private var infrequent: Debounced

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        // On PC/OSX we always know the user has a SteamID and is logged in already.
        precondition(steam.user.loggedOn())
        localUserSteamID = steam.user.getSteamID()

        gameState = .gameMenu // main menu
        stateTransitionTime = engine.gameTickCount
        transitionedGameState = true
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

    func onGameStateChanged() {
    }

    func runFrame() {
        // Get any new data off the network to begin with
        receiveNetworkData()

        // Check if escape has been pressed, we'll use that info in a couple places below
        let escapedPressed = cancelInput.test(now: engine.gameTickCount)

        // Run Steam client callbacks
        steam.runCallbacks()

        // Do work that runs infrequently. we do this every second.
        if infrequent.test(now: engine.gameTickCount) {
            runOccasionally()
        }

        // if we just transitioned state, perform on change handlers
        if transitionedGameState {
            transitionedGameState = false
            onGameStateChanged()
        }

        starField.render()

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

/// Helper to debounce events to avoid one 'esc' press jumping through layers of menus
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
