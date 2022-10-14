//
//  TextureCache.swift
//  SpaceWar
//

import Steamworks
import SteamworksHelpers
import MetalEngine

/// Utility to manage displaying small steam images as textures.
/// Get a specific Steam image RGBA as a game texture
///
/// `SpaceWarClient::GetSteamImageAsTexture()`
struct TextureCache {
    private let steam: SteamAPI
    private let engine: Engine2D
    private var textures: [Int: Texture2D]

    init(steam: SteamAPI, engine: Engine2D) {
        self.steam = steam
        self.engine = engine
        self.textures = [:]
    }

    mutating func getSteamImageAsTexture(imageIndex: Int) -> Texture2D? {
        guard imageIndex > 0 else {
            return nil
        }

        if let texture = textures[imageIndex] {
            return texture
        }

        let image = steam.utils.getImageRGBA(imageIndex: imageIndex)
        guard image.rc, image.width > 0 else {
            return nil
        }

        let texture = engine.createTexture(bytes: image.dest,
                                           width: image.width, height: image.height,
                                           format: .rgba)
        textures[imageIndex] = texture
        return texture
    }
}
