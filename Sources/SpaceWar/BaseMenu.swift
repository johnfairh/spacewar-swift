//
//  BaseMenu.swift
//  SpaceWar
//

import MetalEngine

/// Shared things and constants
@MainActor
private enum Menu {
    static var font: Font2D!

    static let FONT_HEIGHT = Float(24)
    static let ITEM_PADDING = Float(12)

    static var lastReturnKeyTick: Engine2D.TickCount = 0
    static var lastKeyDownTick: Engine2D.TickCount = 0
    static var lastKeyUpTick: Engine2D.TickCount = 0
}

/// General menu class that can draw itself, scroll, and report selection to a callback
@MainActor
class BaseMenu<ItemData: Equatable & MenuItemNamed> {
    private let engine: Engine2D
    private let controller: Controller
    private let onSelection: (ItemData) -> Void

    private var items: [(String, ItemData)]
    private var selectedItem: Int
    private(set) var selectedMenuItem: ItemData?
    private var pushedSelection: ItemData?
    var heading: String

    init(engine: Engine2D, controller: Controller, onSelection: @escaping (ItemData) -> Void) {
        self.engine = engine
        self.controller = controller
        self.onSelection = onSelection

        items = []
        selectedItem = 0
        pushedSelection = nil

        heading = ""

        if Menu.font == nil {
            Menu.font = engine.createFont(style: .proportional, weight: .bold, height: Menu.FONT_HEIGHT)
        }
    }

    // Clear current selection, reset to top (otherwise selection persists on re-present)
    func resetSelection() {
        selectedItem = 0
        selectedMenuItem = nil
    }

    // Clear all menu entries
    func clearMenuItems() {
        items = []
        selectedItem = 0
    }

    // Add a menu item to the menu
    func addItem(_ data: ItemData) {
        items.append((data.menuItemName, data))
    }

    // Save any current selection 'by value', prep for menu rebuild
    func pushSelectedItem() {
        if selectedItem < items.count {
            pushedSelection = items[selectedItem].1
        }
    }

    // Restore a previously 'pushed' selection, after menu rebuild
    func popSelectedItem() {
        guard let pushedSelection else {
            return
        }

        self.pushedSelection = nil

        if let index = items.firstIndex(where: {$0.1 == pushedSelection}) {
            selectedItem = index
        }
    }

    // Run a frame + render
    func runFrame() {
        // Note: The below code uses globals that are shared across all menus to avoid double
        // key press registration, this is so that when you do something like hit return in the pause
        // menu to "go back to main menu" you don't end up immediately registering a return in the
        // main menu afterwards.

        let currentTickCount = engine.frameTimestamp

        // check if the enter key is down, if it is take action
        if engine.isKeyDown(.enter) || controller.isActionActive(.menuSelect) {
            if currentTickCount - 220 > Menu.lastReturnKeyTick {
                Menu.lastReturnKeyTick = currentTickCount
                if selectedItem < items.count {
                    selectedMenuItem = items[selectedItem].1
                    onSelection(selectedMenuItem!)
                }
            }
            // Check if we need to change the selected menu item
        } else if engine.isKeyDown(.down) || controller.isActionActive(.menuDown) {
            if currentTickCount - 140 > Menu.lastKeyDownTick {
                Menu.lastKeyDownTick = currentTickCount
                selectedItem += 1
                if selectedItem == items.count {
                    selectedItem = 0
                }
            }
        } else if engine.isKeyDown(.up) || controller.isActionActive(.menuUp) {
            if currentTickCount - 140 > Menu.lastKeyUpTick {
                Menu.lastKeyUpTick = currentTickCount
                selectedItem -= 1
                if selectedItem < 0 {
                    selectedItem = items.count - 1
                }
            }
        }

        render()
    }

    private func render() {
        if !heading.isEmpty {
            engine.drawText(heading, font: Menu.font, color: .rgb(1, 0.5, 0.5),
                            x: 0, y: 10, width: engine.viewportSize.x, height: Menu.FONT_HEIGHT + Menu.ITEM_PADDING * 2,
                            align: .center, valign: .center)
        }

        let maxMenuItems = 14

        let numItems = items.count

        let startItem: Int
        let endItem: Int
        if numItems > maxMenuItems {
            startItem = max(selectedItem - maxMenuItems / 2, 0)
            endItem = min(startItem + maxMenuItems, numItems)
        } else {
            startItem = 0
            endItem = numItems
        }

        let boxHeight = min(numItems, maxMenuItems) * Int(Menu.FONT_HEIGHT + Menu.ITEM_PADDING)

        var yPos = engine.viewportSize.y / 2.0 - Float(boxHeight / 2)

        func drawText(_ text: String, color: Color2D) {
            engine.drawText(text, font: Menu.font, color: color,
                            x: 0, y: yPos, width: engine.viewportSize.x, height: Menu.FONT_HEIGHT + Menu.ITEM_PADDING,
                            align: .center, valign: .center)
            yPos += Menu.FONT_HEIGHT + Menu.ITEM_PADDING
        }

        if startItem > 0 {
            drawText("... Scroll Up ...", color: .rgb(1, 1, 1))
        }

        for i in startItem..<endItem {
            let item = items[i]
            // Empty strings can be used to space menus, they don't get drawn or selected
            if !item.0.isEmpty {
                if i == selectedItem {
                    drawText("{ \(item.0) }", color: .rgb_i(25, 200, 25))
                } else {
                    drawText(item.0, color: .rgb(1, 1, 1))
                }
            } else {
                yPos += Menu.FONT_HEIGHT + Menu.ITEM_PADDING
            }
        }

        if numItems > endItem {
            drawText("... Scroll Down ...", color: .rgb(1, 1, 1))
        }
    }
}

protocol MenuItemNamed {
    var menuItemName: String { get }
}

extension MenuItemNamed where Self: CustomStringConvertible {
    var menuItemName: String { description }
}

extension MenuItemNamed where Self: CaseIterable & RawRepresentable, Self.RawValue == String {
    var menuItemName: String { rawValue }
}

/// Specialized for common case with an enum permanently holding all the choices
final class StaticMenu<MenuItemEnum> : BaseMenu<MenuItemEnum> where MenuItemEnum: Equatable & CaseIterable & MenuItemNamed {
    private let filter: (MenuItemEnum) -> Bool

    func populate() {
        MenuItemEnum.allCases.forEach {
            if filter($0) {
                addItem($0)
            }
        }
    }

    init(engine: Engine2D, controller: Controller, filter: @escaping (MenuItemEnum) -> Bool = { _ in true }, onSelection: @escaping (MenuItemEnum) -> Void = {_ in }) {
        self.filter = filter
        super.init(engine: engine, controller: controller, onSelection: onSelection)
        populate()
    }
}

