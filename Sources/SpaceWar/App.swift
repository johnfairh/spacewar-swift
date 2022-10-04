//
//  SpaceWarApp.swift
//  SpaceWar
//

import SwiftUI
import MetalEngine

// * Move startup gorp back out to App, pass in SteamAPI, Engine, CommandLineParams
// * Figure out how to do the faster network timer
// * Alert is only during init, move it over
// * Use logger for debug message?  Test it.

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
            MetalEngineView() {
                Self.theClient = SpaceWarClient(engine: $0)
            } frame: { _ in
                Self.theClient?.runFrame()
            }.frame(minWidth: 200, minHeight: 100)
        }
    }

    /// Might need to reach around here from random places, not sure
    static private(set) var theClient: SpaceWarClient?

    /// Quit the entire thing
    static func quit() {
        theClient = nil // shuts down Steam
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

extension Array where Element: Equatable {
    func following(_ match: Element) -> Element? {
        firstIndex(of: match).flatMap { idx in
            idx + 1 < count ? self[idx + 1] : nil
        }
    }
}
