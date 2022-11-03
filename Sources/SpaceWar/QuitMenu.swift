//
//  QuitMenu.swift
//  SpaceWar
//

enum QuitMenuItem: String, CaseIterable, MenuItemNamed {
    case resume = "Resume Game"
    case mainMenu = "Exit to Main Menu"
    case quit = "Exit to Desktop"
}

typealias QuitMenu = StaticMenu<QuitMenuItem>

