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

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        starField = StarField(engine: engine)
    }

    func execCommandLineConnect(params: CmdLineParams) {
    }

    func retrieveEncryptedAppTicket() {
    }

    func runFrame() {
        steam.runCallbacks()
        starField.render()

        if engine.isKeyDown(.printable("Q")) {
            SpaceWarApp.quit()
        }
    }
}
