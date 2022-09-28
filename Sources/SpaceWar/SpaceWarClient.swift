//
//  SpaceWar.swift
//  SpaceWar
//

import Steamworks
import MetalEngine

/// Top-level game control type containing steam client and everything else, corresponds
/// to SpaceWarClient and bits of Main.
///
/// SpaceWarApp holds the only reference to this and clears it when told to quit.
final class SpaceWarClient {
    let steam: SteamAPI
    let engine: Engine2D

    let starField: StarField

    init(engine: Engine2D) {
        self.engine = engine

        guard let steam = SteamAPI(appID: .spaceWar, fakeAppIdTxtFile: true) else {
            preconditionFailure("SteamInit failed")
        }
        self.steam = steam

        starField = StarField(engine: engine)

        engine.setBackgroundColor(.rgb(0, 0, 0))
    }

    func runFrame() {
        steam.runCallbacks()
        starField.render()
    }
}
