//
//  VectorEntity.swift
//  SpaceWar
//

import MetalEngine
import simd

typealias Radians = Float

/// An entity with fixed geometry that has position and acceleration in space, updating itself by frame
/// Subclasses expected to tweak parameters
@MainActor
class VectorEntity {
    let engine: Engine2D
    let collisionRadius: Float
    let maximumVelocity: Float
    var collisionDetectionDisabled: Bool

    private struct Vertex {
        let pos: SIMD2<Float>
        let color: Color2D
    }

    /// Vector of points (always built 2 at a time so it's actually lines)
    private var vertexes: [(Vertex, Vertex)]

    /// Current position (position is at the center of the object)
    var pos: SIMD2<Float>
    /// Previous position
    private(set) var posLastFrame: SIMD2<Float>

    /// The distance travelled since the last frame
    var distanceTraveledLastFrame: Float {
        simd_distance(pos, posLastFrame)
    }

    /// Current velocity - normally computed from acceleration
    var velocity: SIMD2<Float>
    /// Acceleration to be applied next frame
    var acceleration: SIMD2<Float>
    /// Acceleration applied last frame
    private(set) var accelerationLastFrame: SIMD2<Float>

    /// total cumulative rotation that has been applied to this entity
    var accumulatedRotation: Radians
    /// rotation to apply this frame
    var rotationDeltaNextFrame: Radians
    /// rotation which was applied last frame
    private(set) var rotationDeltaLastFrame: Radians

    /// Max velocity in pixels per second
    static nonisolated let DEFAULT_MAXIMUM_VELOCITY: Float = 450

    init(engine: Engine2D, collisionRadius: Float, maximumVelocity: Float = VectorEntity.DEFAULT_MAXIMUM_VELOCITY) {
        self.engine = engine
        self.collisionRadius = collisionRadius
        self.maximumVelocity = maximumVelocity

        self.collisionDetectionDisabled = false

        vertexes = []

        pos = .zero
        // we should have at least one frame Run before
        // anyone asks for a delta, so this shouldn't cause
        // a large initial delta to our starting position, in theory
        posLastFrame = .zero

        velocity = .zero
        acceleration = .zero
        accelerationLastFrame = .zero

        accumulatedRotation = 0
        rotationDeltaNextFrame = 0
        rotationDeltaLastFrame = 0
    }

    /// Add a line to our geometry
    func addLine(xPos0: Float, yPos0: Float, xPos1: Float, yPos1: Float, color: Color2D) {
        vertexes.append((Vertex(pos: .init(xPos0, yPos0), color: color),
                         Vertex(pos: .init(xPos1, yPos1), color: color)))
    }

    /// Clear all lines in the entity
    func clearVertexes() {
        vertexes = []
    }

    /// Run a frame for the vector entity (ie, compute rotation, position, etc...)
    func runFrame() {
        // Accumulate the rotation so we know our current rotation total at all times
        accumulatedRotation.addClippingTo2PI(rotationDeltaNextFrame)
        rotationDeltaLastFrame = rotationDeltaNextFrame
        rotationDeltaNextFrame = 0

        // Update our acceleration, velocity, and finally position
        // Note: The max here is so we don't get massive acceleration if frames for some reason don't run for a bit
        let elapsedSeconds = max(Float(engine.frameDelta) / 1000.0, 0.1)
        velocity += acceleration * elapsedSeconds

        // Make sure velocity does not exceed maximum allowed - this scales it while
        // keeping the aspect ratio consistent
        let linearVelocity = simd_length(velocity)
        if linearVelocity > maximumVelocity {
            let ratio = maximumVelocity / linearVelocity
            velocity *= ratio
        }

        posLastFrame = pos
        pos += velocity * elapsedSeconds

        // Clear acceleration values, child classes should keep reseting it as appropriate each frame
        accelerationLastFrame = acceleration
        acceleration = .zero

        // Check for wrapping around the screen
        pos.clip(to: engine.viewportSize)
    }

    /// Render the entity -- can  override color instead of using the vertex color
    func render(overrideColor: Color2D? = nil) {
        // Compute values which will be used for rotation below
        let rotation = matrix_float2x2(rotation: accumulatedRotation)

        // Iterate our vector of vertexes 2 at a time drawing lines
        vertexes.forEach { v in
            let col0 = overrideColor ?? v.0.color
            let pos0 = rotation * v.0.pos + pos

            let col1 = overrideColor ?? v.1.color
            let pos1 = rotation * v.1.pos + pos

            // Have the game engine draw the actual line (it batches these operations)
            engine.drawLine(x0: pos0.x, y0: pos0.y, color0: col0, x1: pos1.x, y1: pos1.y, color1: col1)
        }
    }

    /// Check if the entity is colliding with the other given entity
    func collides(with target: VectorEntity) -> Bool {
        // Note: Yes, this is a lame way to do collision detection just using a set radius.
        //       I don't care for the moment, just want it running!
        guard !collisionDetectionDisabled && !target.collisionDetectionDisabled else {
            return false
        }

        return simd_distance(pos, target.pos) < collisionRadius + target.collisionRadius
    }
}

extension matrix_float2x2 {
    init(rotation: Radians) {
        let sinRotation = sin(rotation)
        let cosRotation = cos(rotation)
        self.init(columns: (.init(cosRotation, sinRotation),
                            .init(-sinRotation, cosRotation)))
    }
}

extension Radians {
    /// Terrifying routine from the valve source.
    /// Reminds me of a Demis anecdote from rollercoaster tycoon about dividing by zero.
    ///
    /// If the accumulated rotation is > 2pi (360) then wrap it (same for negative direction)
    /// This prevents the value getting really large and losing precision
    mutating func addClippingTo2PI(_ val: Radians) {
        self += val
        var infiniteLoopProtector = 0
        while self >= 2 * .pi && infiniteLoopProtector < 100 {
            self -= 2 * .pi
            infiniteLoopProtector += 1
        }
        infiniteLoopProtector = 0
        while self <= -2 * .pi && infiniteLoopProtector < 100 {
            self += 2 * .pi
            infiniteLoopProtector += 1
        }
    }
}

extension Float {
    /// This is some form of modulo again but scared of floating point
    mutating func clip(to val: Float) {
        if self > val { self -= val }
        else if self < 0 { self += val }
    }
}

extension SIMD2<Float> {
    mutating func clip(to val: SIMD2<Float>) {
        x.clip(to: val.x)
        y.clip(to: val.y)
    }
}
