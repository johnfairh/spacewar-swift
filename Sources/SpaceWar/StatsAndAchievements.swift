//
//  StatsAndAchievements.swift
//  SpaceWar
//

import Foundation
import Steamworks
import MetalEngine

// Stub

final class StatsAndAchievements {
    let steam: SteamAPI
    let engine: Engine2D
    let controller: Controller

    init(steam: SteamAPI, engine: Engine2D, controller: Controller) {
        self.steam = steam
        self.engine = engine
        self.controller = controller
    }

    func runFrame() {}

    func render() {}

    func addDistanceTravelled(_ distance: Float) {}

    func onGameStateChanged(_ state: SpaceWarClient.State) {}
}
