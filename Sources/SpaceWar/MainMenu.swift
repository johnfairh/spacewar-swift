//
//  MainMenu.swift
//  SpaceWar
//

enum MainMenuItem: String, CaseIterable, MenuItemNamed {
    case startServer = "Start New Server"
    case findLANServers = "Find LAN Servers"
    case findInternetServers = "Find Internet Servers"
    case createLobby = "Create Lobby"
    case findLobby = "Find Lobby"
    case gameInstructions = "Instructions"
    case statsAchievements = "Stats and Achievements"
    case leaderboards = "Leaderboards"
    case friendsList = "Friends List"
    case clanChatRoom = "Group Chat Room"
    case remotePlay = "Remote Play"
    case remoteStorage = "Remote Storage"
    case webCallback = "Web Callback"
    case music = "Music Player"
    case workshop = "Workshop Items"
    case htmlSurface = "HTML Page"
    case inGameStore = "In-game Store"
    case overlayAPI = "OverlayAPI"
    case gameExiting = "Exit Game"
}

typealias MainMenu = StaticMenu<MainMenuItem>
