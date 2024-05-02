//
//  Sun.swift
//  SpaceWar
//

import MetalEngine

@MainActor
final class Sun: SpaceWarEntity {
    static let VECTOR_SCALE_FACTOR: Float = 14

    init(engine: Engine2D) {
        super.init(engine: engine, collisionRadius: 2 * Sun.VECTOR_SCALE_FACTOR, affectedByGravity: false)

        let sqrtof2 = Float(2).squareRoot()

        let color: Color2D = .rgb_i(255, 255, 102)

        // Initialize our geometry
        addLine(xPos0: (2.0*Sun.VECTOR_SCALE_FACTOR), yPos0: 0.0, xPos1: (-2.0*Sun.VECTOR_SCALE_FACTOR), yPos1: 0.0, color: color)
        addLine(xPos0: 0.0, yPos0: (2.0*Sun.VECTOR_SCALE_FACTOR), xPos1: 0.0, yPos1: (-2.0*Sun.VECTOR_SCALE_FACTOR), color: color)
        addLine(xPos0: -1.0*sqrtof2*Sun.VECTOR_SCALE_FACTOR, yPos0: sqrtof2*Sun.VECTOR_SCALE_FACTOR, xPos1: sqrtof2*Sun.VECTOR_SCALE_FACTOR, yPos1: -1.0*sqrtof2*Sun.VECTOR_SCALE_FACTOR, color: color)
        addLine(xPos0: sqrtof2*Sun.VECTOR_SCALE_FACTOR, yPos0: sqrtof2*Sun.VECTOR_SCALE_FACTOR, xPos1: -1.0*sqrtof2*Sun.VECTOR_SCALE_FACTOR, yPos1: -1.0*sqrtof2*Sun.VECTOR_SCALE_FACTOR, color: color)

        // Has to be after unlock since the base class will lock in this call
        // JF: Moved this to `runFrame()` because window size not known at init and
        // because window size can change.  Commentary about 'lock in' is wrong.
//        pos = center
    }

    /// Run a frame
    override func runFrame() {
        pos = engine.viewportSize / 2

        // We want to rotate 90 degrees every 800ms (1.57 is 1/2pi, or 90 degrees in radians)
        rotationDeltaNextFrame = Float.pi/2 * Float(engine.frameDelta)/800.0
        super.runFrame()
    }
}
