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

        var connectValue: String {
            switch self {
            case .nothing: return "" // XXX nil
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
        case .findLANServers, .findInternetServers:
            return .waitingForMatch
        default:
            return .atMainMenu
        }
    }

    /// Status to publish for specific main-game states
    var richPresenceStatus: String {
        switch self {
        case .connectingToSteam: return ""
        case .gameMenu: return "At main menu"
        case .startServer: return ""
        case .findLANServers: return "Finding a LAN game"
        case .findInternetServers: return "Finding an internet game"
        case .createLobby: return ""
        case .joinLobby: return ""
        case .gameInstructions: return "Viewing game instructions"
        case .statsAchievements: return "Viewing stats and achievements"
        case .leaderboards: return "Viewing leaderboards"
        case .friendsList: return "Viewing friends list"
        case .clanChatRoom: return "Chatting"
        case .remotePlay: return "Viewing remote play sessions"
        case .remoteStorage: return "Viewing remote storage"
        case .webCallback: return "Viewing web callback example"
        case .music: return "Using music player"
        case .workshop: return "Viewing workshop items"
        case .htmlSurface: return "Using the web"
        case .inGameStore: return "Viewing the item store"
        case .overlayAPI: return "Viewing overlay API examples"
        case .gameExiting: return ""
        }
    }
}

extension SpaceWarClient.State {
    /// Status to publish for specific client states
    var richPresenceStatus: String {
        switch self {
        case .idle: return ""
        case .startServer, .connecting, .waitingForPlayers, .connectionFailure:
            return "Starting a match"
        case .active, .winner, .draw, .quitMenu:
            return "In a match"
        }
    }
}

extension Lobbies.State {
    /// Status to publish for specific client states
    var richPresenceStatus: String {
        switch self {
        case .idle: return ""
        case .creatingLobby: return "Creating a lobby"
        case .inLobby: return "In a lobby"
        case .findLobby: return "Main menu: finding lobbies"
        case .joiningLobby: return "Joining a lobby"
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
