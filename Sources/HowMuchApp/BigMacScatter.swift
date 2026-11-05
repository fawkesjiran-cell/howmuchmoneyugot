import Foundation
import QuartzCore
import SwiftUI

/// A fixed-size gravity sandbox for the Big Mac pile.
///
/// Burgers spawn at a random x inside a narrow drop zone, accelerate downward
/// and physically push each other around on a wider horizontal ledge. A burger
/// knocked past either ledge edge falls through the gap below and is discarded;
/// the hover count still reflects the full number of earned burgers.
final class BigMacPileModel: ObservableObject {
    struct Body: Identifiable {
        let id: Int
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var angle: Double
        var spin: Double
    }

    static let width: CGFloat = 130
    static let height: CGFloat = 104
    static let radius: CGFloat = 7.5
    static let platformY: CGFloat = 92
    static let platformMin: CGFloat = 19
    static let platformMax: CGFloat = 111
    static let fallMin: CGFloat = 10
    static let fallMax: CGFloat = 120
    static let spawnMin: CGFloat = 39
    static let spawnMax: CGFloat = 91
    static let gravity: CGFloat = 900
    static let maxBodies = 200
    static let initialSpawnCap = 36

    @Published private(set) var bodies: [Body] = []

    private var nextID = 0
    private var logicalCount = 0
    private var initialized = false
    private var timer: Timer?
    private var lastTime: CFTimeInterval = 0
    private var accumulator: CFTimeInterval = 0
    private var quietFrames = 0
    private var startTime: CFTimeInterval = 0

    deinit {
        timer?.invalidate()
    }

    func setCount(_ count: Int) {
        let previous = logicalCount
        let firstSync = !initialized
        logicalCount = count
        initialized = true

        if count <= 0 {
            stop()
            bodies = []
            return
        }

        if firstSync {
            let visible = min(count, Self.initialSpawnCap)
            for _ in 0..<visible {
                spawn()
            }
        } else if count > previous {
            let available = max(0, Self.maxBodies - bodies.count)
            let toSpawn = min(count - previous, available, 8)
            for _ in 0..<toSpawn {
                spawn()
            }
        }

        if !bodies.isEmpty {
            quietFrames = 0
            startTime = CACurrentMediaTime()
            start()
        }
    }

    // MARK: - Spawning

    private func spawn() {
        guard bodies.count < Self.maxBodies else { return }

        let x = CGFloat.random(in: Self.spawnMin...Self.spawnMax)
        let y = -Self.radius - CGFloat.random(in: 4...16)
        let body = Body(
            id: nextID,
            x: x,
            y: y,
            vx: CGFloat.random(in: -30...30),
            vy: 0,
            angle: Double.random(in: -20...20),
            spin: Double.random(in: -160...160)
        )
        nextID += 1
        bodies.append(body)
    }

    // MARK: - Simulation loop

    private func start() {
        guard !bodies.isEmpty else {
            stop()
            return
        }
        guard timer == nil else { return }

        lastTime = CACurrentMediaTime()
        accumulator = 0
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard timer != nil else { return }

        let now = CACurrentMediaTime()
        let frameTime = min(1.0 / 30.0, max(1.0 / 120.0, now - lastTime))
        lastTime = now
        accumulator += frameTime

        var next = bodies
        let fixedStep: CFTimeInterval = 1.0 / 120.0
        var steps = 0
        while accumulator >= fixedStep, steps < 4 {
            next = advanced(next, dt: CGFloat(fixedStep))
            accumulator -= fixedStep
            steps += 1
        }
        bodies = next

        if isQuiet(next) {
            quietFrames += 1
        } else {
            quietFrames = 0
        }

        if quietFrames >= 30 || now - startTime > 6 {
            finish()
        }
    }

    private func finish() {
        stop()
        var next = bodies
        for index in next.indices {
            next[index].vx = 0
            next[index].vy = 0
            next[index].spin = 0
        }
        bodies = next
    }

    private func isQuiet(_ current: [Body]) -> Bool {
        current.allSatisfy { body in
            abs(body.vx) < 4
                && abs(body.vy) < 4
                && abs(body.spin) < 10
        }
    }

    // MARK: - Physics

    private func advanced(_ input: [Body], dt: CGFloat) -> [Body] {
        var next = input

        for index in next.indices {
            next[index].vy += Self.gravity * dt
            next[index].x += next[index].vx * dt
            next[index].y += next[index].vy * dt
            next[index].angle += next[index].spin * dt
            next[index].spin *= 0.97
            if abs(next[index].spin) < 2 {
                next[index].spin = 0
            }
        }

        for _ in 0..<5 {
            for index in next.indices {
                resolvePlatform(&next, index)
            }
            if next.count > 1 {
                for i in 0..<(next.count - 1) {
                    for j in (i + 1)..<next.count {
                        resolvePair(&next, i, j)
                    }
                }
            }
        }

        // Keep falling burgers inside a band that is narrower than the
        // clipped display. A full emoji always remains visible at the side,
        // even while it drops past the ledge.
        for index in next.indices {
            if next[index].x < Self.fallMin {
                next[index].x = Self.fallMin
                next[index].vx = 0
            } else if next[index].x > Self.fallMax {
                next[index].x = Self.fallMax
                next[index].vx = 0
            }
        }

        next.removeAll { body in
            body.y - Self.radius > Self.height
        }
        return next
    }

    private func resolvePlatform(_ bodies: inout [Body], _ index: Int) {
        let x = bodies[index].x
        let y = bodies[index].y
        guard x >= Self.platformMin,
              x <= Self.platformMax,
              y >= Self.platformY - Self.radius,
              y <= Self.platformY else { return }

        bodies[index].y = Self.platformY - Self.radius
        if bodies[index].vy > 0 {
            bodies[index].vy = -bodies[index].vy * 0.06
            if abs(bodies[index].vy) < 12 {
                bodies[index].vy = 0
            }
        }
        bodies[index].vx *= 0.965
        let targetSpin = Double(bodies[index].vx / Self.radius)
        bodies[index].spin += (targetSpin - bodies[index].spin) * 0.10
        bodies[index].spin *= 0.94
        if abs(bodies[index].vx) < 0.5 {
            bodies[index].vx = 0
        }
    }

    private func resolvePair(_ bodies: inout [Body], _ i: Int, _ j: Int) {
        let minDist = Self.radius * 2
        var dx = bodies[j].x - bodies[i].x
        var dy = bodies[j].y - bodies[i].y
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared < minDist * minDist else { return }

        var distance = sqrt(distanceSquared)
        if distance < 0.0001 {
            dx = 1
            dy = 0
            distance = 0.0001
        }

        let nx = dx / distance
        let ny = dy / distance
        let push = (minDist - distance) * 0.5
        bodies[i].x -= nx * push
        bodies[i].y -= ny * push
        bodies[j].x += nx * push
        bodies[j].y += ny * push

        let rvx = bodies[j].vx - bodies[i].vx
        let rvy = bodies[j].vy - bodies[i].vy

        let normalVelocity = rvx * nx + rvy * ny
        if normalVelocity < 0 {
            let impulse = -(1 + 0.06) * normalVelocity * 0.5
            bodies[i].vx -= impulse * nx
            bodies[i].vy -= impulse * ny
            bodies[j].vx += impulse * nx
            bodies[j].vy += impulse * ny
        }

        let tx = -ny
        let ty = nx
        let tangentVelocity = rvx * tx + rvy * ty
        let tangentImpulse = -tangentVelocity * 0.38 * 0.5
        bodies[i].vx -= tangentImpulse * tx
        bodies[i].vy -= tangentImpulse * ty
        bodies[j].vx += tangentImpulse * tx
        bodies[j].vy += tangentImpulse * ty

        bodies[i].spin += Double(tangentVelocity) * 0.012
        bodies[j].spin -= Double(tangentVelocity) * 0.012
    }
}

/// The amount's right-hand blank area: a random-x gravity pile with a wider
/// ledge. The exact count is only shown on hover.
struct BigMacScatterField: View {
    static let width = BigMacPileModel.width
    static let height = BigMacPileModel.height

    let count: Int
    let countText: String
    let helpText: String

    @ObservedObject var pile: BigMacPileModel
    @State private var hovering = false

    var body: some View {
        ZStack {
            ForEach(pile.bodies) { body in
                Text("🍔")
                    .font(.system(size: 15))
                    .rotationEffect(.degrees(body.angle))
                    .position(x: body.x, y: body.y)
                    .opacity(opacity(for: body))
                    .compositingGroup()
                    .shadow(color: Palette.ink.opacity(0.14), radius: 2, y: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .clipped()
        .overlay(alignment: .topTrailing) {
            Text(countText)
                .font(AppFont.geist(9, .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(
                    Capsule()
                        .fill(Palette.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Palette.line, lineWidth: 0.7)
                )
                .shadow(color: Palette.ink.opacity(0.06), radius: 3, y: 1)
                .offset(x: -1, y: 4)
                .opacity(hovering ? 1 : 0)
                .scaleEffect(hovering ? 1 : 0.92, anchor: .topTrailing)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onAppear {
            pile.setCount(count)
        }
        .onChange(of: count) { newCount in
            pile.setCount(newCount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(countText)
        .accessibilityValue(helpText)
    }

    private func opacity(for body: BigMacPileModel.Body) -> Double {
        let fadeStart = BigMacPileModel.platformY + 2
        guard body.y > fadeStart else { return 1 }
        let remaining = (BigMacPileModel.height + BigMacPileModel.radius - body.y)
            / (BigMacPileModel.height + BigMacPileModel.radius - fadeStart)
        return max(0, min(1, Double(remaining)))
    }
}
