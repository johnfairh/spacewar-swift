//
//  RichPresence.swift
//  SpaceWar
//

import Steamworks

// Helpers to pull together the various rich presence published info

/// Namespace
enum RichPresence {
    /// Enum of translated status values that can go into the `steam_display` thing
    /// Raw values match keys in the vdf translation file
    enum GameStatus: String {
        case atMainMenu = "AtMainMenu"
        case waitingForMatch = "WaitingForMatch"
        case winning = "Winning"
        case losing = "Losing"
        case tied = "Tied"
    }

    /// Things we can be connected to that drive the `connect` thing
    enum Connected {
        case nothing
        case server(Int, UInt16)
        case lobby(SteamID)

        var connectValue: String {
            switch self {
            case .nothing: return "" // XXX nil
            case .server(let ip, let port): return "+connect \(ip):\(port)"
            case .lobby(let steamID): return "+connect_lobby \(steamID.asUInt64)"
            }
        }
    }
}

extension SteamFriends {
    /// Status, english, fine-grained, to 'view game info'
    func setRichPresence(status: String) {
        _ = setRichPresence(key: "status", value: status)
    }

    /// Status, translated, to the steam UI, see richpresenceloc.vdf - this version for use when not in a game
    func setRichPresence(gameStatus: RichPresence.GameStatus) {
        _ = setRichPresence(key: "gamestatus", value: gameStatus.rawValue) /*XXX discard*/
        _ = setRichPresence(key: "steam_display", value: "#StatusWithoutScore")
    }

    /// Status, translated, to the steam UI, see richpresenceloc.vdf - this version for use when in a game
    func setRichPresence(gameStatus: RichPresence.GameStatus, score: Int) {
        _ = setRichPresence(key: "gamestatus", value: gameStatus.rawValue)
        _ = setRichPresence(key: "score", value: String(score))
        _ = setRichPresence(key: "steam_display", value: "#StatusWithScore")
    }

    /// Associated player group, if any
    func setRichPresence(playerGroup: SteamID?) {
        let value = playerGroup.map { String($0.asUInt64) } ?? ""
        _ = setRichPresence(key: "steam_player_group", value: value)
    }

    /// Connection parameters - connected to server/lobby/nothing
    func setRichPresence(connectedTo: RichPresence.Connected) {
        _ = setRichPresence(key: "connect", value: connectedTo.connectValue)
    }
}
