//
//  SpaceWarEntity.swift
//  SpaceWar
//

import MetalEngine
import simd

/// A `SpaceWarEntity` is just like a `VectorEntity`, except it knows how
/// to apply gravity from the SpaceWar Sun
class SpaceWarEntity: VectorEntity {
    private let affectedByGravity: Bool

    init(engine: Engine2D, collisionRadius: Float, affectedByGravity: Bool, maximumVelocity: Float = VectorEntity.DEFAULT_MAXIMUM_VELOCITY) {
        self.affectedByGravity = affectedByGravity
        super.init(engine: engine, collisionRadius: collisionRadius, maximumVelocity: maximumVelocity)
    }

    static let MIN_GRAVITY = Float(15) // pixels per second per second

    override func runFrame() {
        if affectedByGravity {
            // The suns gravity, compute that here, sun is always at the center of the screen [JF: !!!]
            let posSun = engine.viewportSize / 2

            #if true // XXX CxxInterop
            let distancePower = max(my_distance_squared(posSun, pos), 1)
            #else
            let distancePower = max(simd_distance_squared(posSun, pos), 1) // gravity power falls off exponentially; guard div0
            #endif

            let factor = min(100000.0 / distancePower, SpaceWarEntity.MIN_GRAVITY) // arbitrary value for power of gravity

            let direction = my_normalize(pos - posSun) // XXX CxxInterop simd_normalize(pos - posSun)

            // Set updated acceleration
            acceleration -= factor * direction
        }

        super.runFrame()
    }
}

// Swift C++ interop makes simd_vector_add() not link, which loads depends on ... baffling
func my_distance_squared(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let xs = pow(a.x - b.x, 2)
    let ys = pow(a.y - b.y, 2)
    return xs + ys
}

func my_distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    sqrt(my_distance_squared(a, b))
}

func my_length(_ v: SIMD2<Float>) -> Float {
    sqrt(pow(v.x, 2) + pow(v.y, 2))
}

private func my_normalize(_ v: SIMD2<Float>) -> SIMD2<Float> {
    let len = my_length(v)
    return [v.x / len, v.y / len]
}
