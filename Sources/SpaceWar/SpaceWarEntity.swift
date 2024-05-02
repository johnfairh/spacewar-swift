//
//  SpaceWarEntity.swift
//  SpaceWar
//

import MetalEngine
import simd

/// A `SpaceWarEntity` is just like a `VectorEntity`, except it knows how
/// to apply gravity from the SpaceWar Sun
@MainActor
class SpaceWarEntity: VectorEntity {
    private let affectedByGravity: Bool

    init(engine: Engine2D, collisionRadius: Float, affectedByGravity: Bool, maximumVelocity: Float = VectorEntity.DEFAULT_MAXIMUM_VELOCITY) {
        self.affectedByGravity = affectedByGravity
        super.init(engine: engine, collisionRadius: collisionRadius, maximumVelocity: maximumVelocity)
    }

    static nonisolated let MIN_GRAVITY = Float(15) // pixels per second per second

    override func runFrame() {
        if affectedByGravity {
            // The suns gravity, compute that here, sun is always at the center of the screen [JF: !!!]
            let posSun = engine.viewportSize / 2

            let distancePower = max(simd_distance_squared(posSun, pos), 1) // gravity power falls off exponentially; guard div0

            let factor = min(100000.0 / distancePower, SpaceWarEntity.MIN_GRAVITY) // arbitrary value for power of gravity

            let direction = simd_normalize(pos - posSun)

            // Set updated acceleration
            acceleration -= factor * direction
        }

        super.runFrame()
    }
}
