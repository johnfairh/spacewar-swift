//
//  RichPresence.swift
//  SpaceWar
//

import Steamworks

/// Helpers to pull together the various rich presence published info.  Single point of truth for magic
/// string keys and full list of strings published to them.

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

        var connectValue: String? {
            switch self {
            case .nothing: return nil
            case .server(let ip, let port): return "+connect \(ip):\(port)"
            case .lobby(let steamID): return "+connect_lobby \(steamID.asUInt64)"
            }
        }
    }
}

extension SpaceWarMain.State {
    /// GameStatus to publish for specific main-game states
    var richPresenceGameStatus: RichPresence.GameStatus {
        switch self {
        case .menuItem(.findLANServers), .menuItem(.findInternetServers):
            return .waitingForMatch
        default:
            return .atMainMenu
        }
    }

    /// Status to publish for specific main-game states
    var richPresenceStatus: String? {
        switch self {
        case .connectingToSteam: return nil
        case .mainMenu: return "At main menu"
        case .menuItem(.startServer): return nil
        case .menuItem(.findLANServers): return "Finding a LAN game"
        case .menuItem(.findInternetServers): return "Finding an internet game"
        case .menuItem(.createLobby): return nil
        case .menuItem(.findLobby): return nil
        case .menuItem(.gameInstructions): return "Viewing game instructions"
        case .menuItem(.statsAchievements): return "Viewing stats and achievements"
        case .menuItem(.leaderboards): return "Viewing leaderboards"
        case .menuItem(.friendsList): return "Viewing friends list"
        case .menuItem(.clanChatRoom): return "Chatting"
        case .menuItem(.remotePlay): return "Viewing remote play sessions"
        case .menuItem(.remoteStorage): return "Viewing remote storage"
        case .menuItem(.webCallback): return "Viewing web callback example"
        case .menuItem(.music): return "Using music player"
        case .menuItem(.workshop): return "Viewing workshop items"
        case .menuItem(.htmlSurface): return "Using the web"
        case .menuItem(.inGameStore): return "Viewing the item store"
        case .menuItem(.overlayAPI): return "Viewing overlay API examples"
        case .menuItem(.gameExiting): return nil
        }
    }
}

extension SpaceWarClient.State {
    /// Status to publish for specific client states
    var richPresenceStatus: String? {
        switch self {
        case .idle: return nil
        case .startServer, .connecting, .waitingForPlayers, .connectionFailure:
            return "Starting a match"
        case .active, .winner, .draw, .quitMenu:
            return "In a match"
        }
    }
}

extension Lobbies.State {
    /// Status to publish for specific client states
    var richPresenceStatus: String? {
        switch self {
        case .idle: return nil
        case .creatingLobby: return "Creating a lobby"
        case .inLobby: return "In a lobby"
        case .findLobby: return "Main menu: finding lobbies"
        case .joiningLobby: return "Joining a lobby"
        }
    }
}

extension SteamFriends {
    /// Status, english, fine-grained, to 'view game info'
    func setRichPresence(status: String?) {
        setRichPresence(key: "status", value: status)
    }

    /// Status, translated, to the steam UI, see richpresenceloc.vdf - this version for use when not in a game
    func setRichPresence(gameStatus: RichPresence.GameStatus) {
        setRichPresence(key: "gamestatus", value: gameStatus.rawValue)
        setRichPresence(key: "steam_display", value: "#StatusWithoutScore")
    }

    /// Status, translated, to the steam UI, see richpresenceloc.vdf - this version for use when in a game
    func setRichPresence(gameStatus: RichPresence.GameStatus, score: Int) {
        setRichPresence(key: "gamestatus", value: gameStatus.rawValue)
        setRichPresence(key: "score", value: String(score))
        setRichPresence(key: "steam_display", value: "#StatusWithScore")
    }

    /// Associated player group, if any
    func setRichPresence(playerGroup: SteamID?) {
        let value = playerGroup.flatMap { $0.isValid ? String($0.asUInt64) : nil }
        setRichPresence(key: "steam_player_group", value: value)
    }

    /// Connection parameters - connected to server/lobby/nothing
    func setRichPresence(connectedTo: RichPresence.Connected) {
        setRichPresence(key: "connect", value: connectedTo.connectValue)
    }
}
