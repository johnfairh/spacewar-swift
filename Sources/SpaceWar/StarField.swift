//
//  StarField.swift
//  SpaceWar
//
//  Straight port

import MetalEngine

final class StarField {
    private static let STAR_COUNT = 600

    private struct Vertex {
        let x, y: Float
        let color: Color2D

        init(x: Float, y: Float, gray: Float) {
            self.x = x
            self.y = y
            self.color = .rgb(gray, gray, gray)
        }
    }

    private let engine: Engine2D
    private var size: SIMD2<Float> = .zero
    private var stars: [Vertex] = []
    private var scrollCount = 0

    init(engine: Engine2D) {
        self.engine = engine
    }

    /// Generate star positions for the current size
    private func reset() {
        size = engine.viewportSize
        stars = []
        stars.reserveCapacity(Self.STAR_COUNT)
        scrollCount = 0
        for _ in 0..<Self.STAR_COUNT {
            stars.append(Vertex(x: Float.random(in: 0..<size.x),
                                y: Float.random(in: 0..<size.y),
                                gray: Float.random(in: 0.2..<1.0))) // visible shade of gray
        }
    }

    /// Render the star field
    func render() {
        if engine.viewportSize != size {
            reset()
        }

        scrollCount += 1

        stars.forEach { star in
            let scoot = Float(scrollCount) * star.color.r / 4.0 // brighter->faster, max .25/frame
            let newy = star.y - scoot // go up
            engine.drawPoint(x: star.x, y: newy < 0 ? newy + size.y : newy, color: star.color)
        }
        engine.flushPoints() // make them behind everything else
    }
}
