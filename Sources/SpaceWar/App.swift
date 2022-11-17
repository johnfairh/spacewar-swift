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
        // Set our log handler before SteamAPI creates a logger
        SWLogHandler.setup()
        LoggingSystem.bootstrap(SWLogHandler.init)

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
        if !steam.input.initialize(explicitlyCallRunFrame: false) {
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

import Logging

/// A `LogHandler` which logs to stdout and a file -- big hack yikes need to find a proper logger
struct SWLogHandler: LogHandler {

    static func setup() {
        unlink(Self.LOGFILE)
    }

    static let LOGFILE = "/Users/johnf/project/swift-spacewar/latest-log"

    /// Create a `SyslogLogHandler`.
    public init(label: String) {
        self.label = label
    }

    public let label: String

    public var logLevel: Logger.Level = .info

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? prettyMetadata
            : prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        let msg = "\(self.timestamp()) \(level) \(label) :\(prettyMetadata.map { " \($0)" } ?? "") [\(source)] \(message)"

        print(msg)
        let f = fopen(Self.LOGFILE, "a")
        fputs("\(msg)\n", f)
        fclose(f)
    }

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            prettyMetadata = prettify(metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        !metadata.isEmpty
            ? metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
            : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%H:%M:%S%z", localTime)
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}
