//
//  SpaceWarApp.swift
//  SpaceWar
//

import SwiftUI
import Steamworks
import MetalEngine

/// SwiftUI / OS startup layer, bits of gorpy steam init, singleton management, CLI parsing
///
/// Don't actually create the client or set up Steam until the engine starts up and gives
/// us a context to create objects and hang stuff on.
@main
struct SpaceWarApp: App {
    init() {
#if SWIFT_PACKAGE
        // Some nonsense to make the app work properly when built outside of Xcode
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            MetalEngineView() { engine in
                // Steam init
                let steam = initSteam()

                let main = SpaceWarMain(engine: engine, steam: steam)

                // Black background
                engine.setBackgroundColor(.rgb(0, 0, 0))

                // If there are no params on the process command line then check in the Steam URL.
                if let cmdLineParams = CmdLineParams() ??
                    CmdLineParams(launchString: steam.apps.getLaunchCommandLine().commandLine) {
                    main.execCommandLineConnect(params: cmdLineParams)
                }

                // test a user specific secret before entering main loop
                Steamworks_TestSecret()

                // XXX think this is just a demo, move it somewhere else?
                main.retrieveEncryptedAppTicket()

                // Save the ref
                Self.instance = main
            } frame: { _ in
                Self.instance?.runFrame()
            }.frame(minWidth: 200, minHeight: 100)
        }
    }

    /// Might need to reach around here from random places, not sure
    static private(set) var instance: SpaceWarMain?

    /// Steam API initialization dance
    private func initSteam() -> SteamAPI {
        // Init Steam CEG
        /* XXX this needs integrating into `SteamApi` for proper sequencing; tricky because doesn't exist... */
        if !Steamworks_InitCEGLibrary() {
            alert("Fatal Error", "Steam must be running to play this game (InitDrmLibrary() failed).");
            preconditionFailure("Steamworks_InitCEGLibrary() failed");
        }

        guard let steam = SteamAPI(appID: .spaceWar, fakeAppIdTxtFile: true) else {
            alert("Fatal Error", "Steam must be running to play this game (SteamAPI_Init() failed).");
            preconditionFailure("SteamInit failed")
        }

        // Debug handlers
        steam.useLoggerForSteamworksWarnings()
        steam.networkingUtils.useLoggerForDebug(detailLevel: .everything)
        SteamAPI.logger.logLevel = .debug

        // Ensure that the user has logged into Steam. This will always return true if the game is launched
        // from Steam, but if Steam is at the login prompt when you run your game from the debugger, it
        // will return false.
        if !steam.user.loggedOn() {
            alert("Fatal Error", "Steam user must be logged in to play this game (SteamUser()->BLoggedOn() returned false).");
            preconditionFailure("Steam user is not logged in")
        }

        // do a DRM self check
        Steamworks_SelfCheck();

        // Steam Input
        if !steam.input.initialize(explicitlyCallRunFrame: false) /* XXX setting? */ {
            alert("Fatal Error", "SteamInput()->Init failed.");
            preconditionFailure("SteamInput()->Init failed.");
        }

#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif

        guard let steamInputManifestURL = bundle.url(forResource: "steam_input_manifest", withExtension: "vdf") else {
            alert("Fatal Error", "SteamInput() VDF missing.")
            preconditionFailure("Can't find steam_input_manifest.vdf in module bundle")
        }
        let rc = steam.input.setInputActionManifestFilePath(inputActionManifestAbsolutePath: steamInputManifestURL.path)
        OutputDebugString("SteamInput VDF load: \(rc)")

        return steam
    }

    private func alert(_ caption: String, _ text: String) {
        OutputDebugString("ALERT: \(caption): \(text)\n")
        let alert = NSAlert.init()
        alert.messageText = caption
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Quit the entire thing
    static func quit() {
        instance = nil // shuts down Steam

        // Shutdown Steam CEG (apparently after SteamAPI_Shutdown()) XXX integrate properly
        Steamworks_TermCEGLibrary();

        NSApp.terminate(self)
    }
}

struct CmdLineParams {
    let serverAddress: String?
    let lobbyID: String?

    private var isEmpty: Bool {
        serverAddress == nil && lobbyID == nil
    }

    private init?(args: [String]) {
        serverAddress = args.following("+connect")
        lobbyID = args.following("+connect_lobby")
        if isEmpty {
            return nil
        }
    }

    init?() {
        self.init(args: ProcessInfo.processInfo.arguments)
    }

    init?(launchString: String) {
        self.init(args: launchString.split(separator: " ").map { String($0) })
    }
}

private extension Array where Element: Equatable {
    func following(_ match: Element) -> Element? {
        firstIndex(of: match).flatMap { idx in
            idx + 1 < count ? self[idx + 1] : nil
        }
    }
}

/// Top-level debug logging
func OutputDebugString(_ msg: String) {
    SteamAPI.logger.debug(.init(stringLiteral: msg))
}

/// CEG -- don't think this exists on macOS, we don't have it at any rate
func Steamworks_InitCEGLibrary() -> Bool { true }
func Steamworks_TermCEGLibrary() {}
func Steamworks_TestSecret() {}
func Steamworks_SelfCheck() {}
