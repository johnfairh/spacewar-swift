//
//  SpaceWarApp.swift
//  SpaceWar
//

import SwiftUI
import Steamworks
import MetalEngine

import Dispatch

/// SwiftUI / OS startup layer, bits of gorpy steam init, singleton management, CLI parsing
///
/// Don't actually create the client or set up Steam until the engine starts up and gives
/// us a context to create objects and hang stuff on.
@main
struct SpaceWarApp: App {
    init() {
        // Some nonsense to simulate a library that probably doesn't exist
        Steamworks_InstallCEGHooks(initCEG: Steamworks_InitCEGLibrary, termCEG: Steamworks_TermCEGLibrary)

#if SWIFT_PACKAGE
        // Some nonsense to make the app work properly when built outside of Xcode.
        // We are before `NSApplicationMain` here so queue it.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            MetalEngineView(preferredFPS: Misc.MAX_CLIENT_AND_SERVER_FPS) { engine in
                // Steam init
                let (steam, controller) = initSteam()

                let main = SpaceWarMain(engine: engine, steam: steam, controller: controller)

                // test a user-specific secret before entering main loop
                Steamworks_TestSecret()

                // This is just a demo, no functional use in this program
                main.retrieveEncryptedAppTicket()

                // Save the ref
                Self.instance = main
            } frame: { _ in
                Self.instance?.runFrame()
            }.frame(maxWidth: 1024, maxHeight: 768)
        }
    }

    /// Might need to reach around here from random places, not sure
    static private(set) var instance: SpaceWarMain?

    /// Steam API initialization dance
    private func initSteam() -> (SteamAPI, Controller) {
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
        if !steam.input.initialize(explicitlyCallRunFrame: false)
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

        return (steam, Controller(steam: steam))
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

        NSApp.terminate(self)
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
