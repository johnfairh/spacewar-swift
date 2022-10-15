//
//  CmdLineParams.swift
//  SpaceWar
//

import Foundation
import Steamworks

/// Type and utils to wrap up dealing with parsing command line parameters
/// XXX xref RichPresence.Connect stuff
struct CmdLineParams: CustomStringConvertible {
    let serverAddress: String?
    let lobbyID: String?

    private var isEmpty: Bool {
        serverAddress == nil && lobbyID == nil
    }

    /// Debug
    var description: String {
        let params = [
            serverAddress.map { "+connect \($0)" },
            lobbyID.map { "+connect_lobby \($0)" }
        ]
        return "[\(params.compactMap { $0 }.joined(separator: ", "))]"
    }

    private init?(args: [String]) {
        serverAddress = args.following("+connect")
        lobbyID = args.following("+connect_lobby")
        if isEmpty {
            return nil
        }
    }

    /// Initialize using the current process's native arguments
    init?() {
        self.init(args: ProcessInfo.processInfo.arguments)
    }

    /// Initialize from a string of space-separated parameters from somewhere
    init?(launchString: String) {
        self.init(args: launchString.split(separator: " ").map { String($0) })
    }

    /// Initialize from the Steam 'launch command line' that can change over time as URLs are dispatched
    init?(steam: SteamAPI) {
        self.init(launchString: steam.apps.getLaunchCommandLine().commandLine)
    }
}

private extension Array where Element: Equatable {
    func following(_ match: Element) -> Element? {
        firstIndex(of: match).flatMap { idx in
            idx + 1 < count ? self[idx + 1] : nil
        }
    }
}

