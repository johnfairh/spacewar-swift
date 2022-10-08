//
//  SpaceWarMain.swift
//  SpaceWar
//

import Steamworks
import MetalEngine
import Foundation

/// Top-level game control type holding ref to the Steam client and everything else.
///
/// Corresponds to the non-core-game parts of SpaceWarClient, attempting to split
/// up and make sense of that monster.
///
/// SpaceWarApp holds the only reference to this and clears it when told to quit.
///
/// The entire architecture of this program is cruft and accretion
final class SpaceWarMain {
    let steam: SteamAPI
    let engine: Engine2D

    let starField: StarField

    init(engine: Engine2D, steam: SteamAPI) {
        self.engine = engine
        self.steam = steam

        starField = StarField(engine: engine)

        Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { [weak self] _ in
            self?.receiveNetworkData()
        }
    }

    func execCommandLineConnect(params: CmdLineParams) {
    }

    func retrieveEncryptedAppTicket() {
    }

    func runFrame() {
        receiveNetworkData()
        steam.runCallbacks()
        starField.render()

        if engine.isKeyDown(.printable("Q")) {
            SpaceWarApp.quit()
        }
    }

    /// Called at the start of each frame and also between frames
    func receiveNetworkData() {
    }
}
