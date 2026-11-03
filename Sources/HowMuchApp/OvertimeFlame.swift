import SwiftUI
import Vortex

/// The ticking session amount. In overtime it receives a fiery aura inspired by
/// a maxed soul-gauge combo counter.
struct OvertimeAmount: View {
    let symbol: String
    let amount: String
    let isOvertime: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fireLight = Color(hex: 0xFFFDF2)
    private let fireGold = Color(hex: 0xFFE58A)
    private let fireOrange = Color(hex: 0xFFB13B)
    private let fireRed = Color(hex: 0xFF5A14)

    var body: some View {
        Group {
            if isOvertime {
                if reduceMotion {
                    styledAmount
                        .background(staticGlow)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let pulse = 1.0 + 0.015 * sin(time * 3.2)
                        styledAmount
                            .scaleEffect(pulse, anchor: .leading)
                            .background(
                                ZStack {
                                    staticGlow
                                    OvertimeParticles()
                                }
                                .frame(width: 344, height: 122)
                                .offset(x: 8, y: 1)
                                .allowsHitTesting(false)
                            )
                    }
                }
            } else {
                amountLabel
            }
        }
        .compositingGroup()
    }

    private var amountLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(symbol)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(symbolStyle)
            Text(amount)
                .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(amountStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }

    private var styledAmount: some View {
        amountLabel
            .shadow(color: Color(hex: 0x3A0900).opacity(0.55), radius: 1.5)
            .shadow(color: fireOrange.opacity(0.62), radius: 10)
            .shadow(color: fireRed.opacity(0.32), radius: 23)
    }

    private var amountStyle: AnyShapeStyle {
        guard isOvertime else { return AnyShapeStyle(Palette.heroText) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [fireLight, fireGold, Color(hex: 0xFFC447)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var symbolStyle: AnyShapeStyle {
        guard isOvertime else { return AnyShapeStyle(Palette.heroText.opacity(0.55)) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [fireLight.opacity(0.90), fireGold.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// A static warm halo is kept for Reduce Motion users.
    private var staticGlow: some View {
        RadialGradient(
            colors: [
                fireOrange.opacity(0.22),
                fireGold.opacity(0.08),
                .clear
            ],
            center: .center,
            startRadius: 1,
            endRadius: 170
        )
        .frame(width: 344, height: 122)
        .blur(radius: 6)
        .allowsHitTesting(false)
    }
}

/// Vortex's fire preset is tuned to wrap the big number rather than fill the
/// whole hero card.
private struct OvertimeParticles: View {
    @State private var system = OvertimeFire.makeSystem()

    var body: some View {
        VortexView(system, targetFrameRate: 30) {
            FlameParticleShape()
                .fill(.white)
                .frame(width: 30, height: 42)
                .blur(radius: 3)
                .opacity(0.82)
                .blendMode(.plusLighter)
                .tag("flame")

            Circle()
                .fill(.white)
                .frame(width: 7)
                .blur(radius: 1.5)
                .opacity(0.9)
                .blendMode(.plusLighter)
                .tag("ember")
        }
    }
}

private enum OvertimeFire {
    static func makeSystem() -> VortexSystem {
        let system = VortexSystem.fire.makeUniqueCopy()
        system.tags = ["flame", "flame", "flame", "ember"]
        system.position = [0.5, 0.80]
        system.shape = .box(width: 0.78, height: 0.02)
        system.birthRate = 68
        system.speed = 0.76
        system.speedVariation = 0.30
        system.angle = .degrees(0)
        system.angleRange = .degrees(26)
        system.lifespan = 1.00
        system.lifespanVariation = 0.32
        system.colors = .ramp(
            color(0xFFB13B),
            color(0xFF7A00),
            color(0xE33A00),
            color(0x8C1400).opacity(0.35),
            color(0x5A0A00).opacity(0)
        )
        system.size = 0.56
        system.sizeVariation = 0.44
        system.sizeMultiplierAtDeath = 0.16
        system.angularSpeed = [0, 0, 0.25]
        system.angularSpeedVariation = [0, 0, 0.35]
        system.attractionStrength = 0
        return system
    }

    private static func color(_ hex: UInt32, opacity: Double = 1) -> VortexSystem.Color {
        VortexSystem.Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}


private struct FlameParticleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * 0.55, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.64),
            control1: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.16),
            control2: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.48, y: rect.maxY),
            control1: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.84),
            control2: CGPoint(x: rect.minX + w * 0.18, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.94, y: rect.minY + h * 0.62),
            control1: CGPoint(x: rect.minX + w * 0.84, y: rect.maxY),
            control2: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.55, y: rect.minY),
            control1: CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.40),
            control2: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.16)
        )
        path.closeSubpath()
        return path
    }
}
