//
//  SpaceWarApp.swift
//  SpaceWar
//

import SwiftUI
import MetalEngine

/// SwiftUI / OS startup layer, bits of gorpy singleton management and CLI parsing
///
/// Don't actually create the client or set up Steam until the engine starts up and gives
/// us a context to create objects and hang stuff on.
@main
struct SpaceWarApp: App {
    /// Program entrypoint
    init() {
#if SWIFT_PACKAGE
        // Some nonsense to make the app work properly when built outside of Xcode
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
#endif
        // command-line stuff?
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
        NSApp.terminate(self)
    }
}
