import SwiftUI
import Vortex

/// The ticking session amount. In overtime the numerals themselves burn: every
/// glyph is filled with flowing fire under a white-hot molten core, and only a
/// tight glow follows the letterforms. Nothing is painted behind or below the
/// number, so the fire reads as the digits rather than as a bed beneath them.
struct OvertimeAmount: View {
    let symbol: String
    let amount: String
    let isOvertime: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if isOvertime {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    overtimeSymbol

                    Group {
                        if reduceMotion {
                            burningAmount(time: 4.6, animated: false)
                        } else {
                            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                                burningAmount(
                                    time: timeline.date.timeIntervalSinceReferenceDate,
                                    animated: true
                                )
                            }
                        }
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    symbolLabel(AnyShapeStyle(Palette.faint))
                    amountLabel(amount, style: AnyShapeStyle(Palette.ink))
                }
            }
        }
        .compositingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(symbol + amount)
    }

    // MARK: - Fire

    /// The currency mark stays a solid warm glyph so the amount is still
    /// immediately legible; the digits themselves carry the fire.
    private var overtimeSymbol: some View {
        symbolLabel(AnyShapeStyle(Palette.ember))
            .shadow(
                color: Palette.ember.opacity(colorScheme == .dark ? 0.28 : 0.12),
                radius: 3
            )
    }

    private func burningAmount(time: Double, animated: Bool) -> some View {
        let separator = Locale.current.decimalSeparator ?? "."
        guard let split = amount.range(of: separator) else {
            return AnyView(burningDigits(amount, time: time, animated: animated))
        }

        let whole = String(amount[..<split.lowerBound])
        let fraction = String(amount[split.upperBound...])

        return AnyView(
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                burningDigits(whole, time: time, animated: animated)

                Text(separator)
                    .font(AppFont.geist(46, .semibold))
                    .foregroundStyle(Palette.ember)
                    .shadow(
                        color: Palette.ember.opacity(colorScheme == .dark ? 0.30 : 0.14),
                        radius: 2
                    )

                burningDigits(fraction, time: time, animated: animated)
            }
        )
    }

    private func burningDigits(_ text: String, time: Double, animated: Bool) -> some View {
        let pulse = CGFloat(1 + (animated ? 0.008 * sin(time * 3.1) : 0))
        let rim = colorScheme == .dark
            ? Color(hex: 0x1A0A04).opacity(0.35)
            : Color(hex: 0x2A0A04).opacity(0.72)

        return burningLabel(text, time: time, animated: animated)
            .scaleEffect(pulse, anchor: .leading)
            .shadow(color: rim, radius: 0.1, x: 0.45, y: 0)
            .shadow(color: rim, radius: 0.1, x: -0.45, y: 0)
            .shadow(color: rim, radius: 0.1, x: 0, y: 0.45)
            .shadow(color: rim, radius: 0.1, x: 0, y: -0.45)
            .shadow(
                color: Color(hex: 0xFF8A10).opacity(colorScheme == .dark ? 0.40 : 0.22),
                radius: 4.5
            )
            .shadow(
                color: Color(hex: 0xFF3200).opacity(colorScheme == .dark ? 0.25 : 0.12),
                radius: 10,
                y: -1.5
            )
    }

    private func burningLabel(_ text: String, time: Double, animated: Bool) -> some View {
        let shape = amountLabel(text, style: AnyShapeStyle(Color.white))

        return shape
            .overlay {
                FlameBody(time: time, animated: animated)
            }
            .overlay {
                moltenCoreLayer(text: text, animated: animated)
                    .blendMode(.plusLighter)
            }
            .mask(shape)
            .compositingGroup()
    }

    /// The white-hot centre of each stroke: a blurred copy of the glyphs tinted
    /// from white-gold at the top to deep orange at the bottom. Because it is
    /// blurred and then clipped by the glyph, each stroke keeps a hot core with
    /// a slightly cooler, textured rim.
    private func moltenCoreLayer(text: String, animated: Bool) -> some View {
        ZStack {
            moltenCore(text, blur: 3.2, opacity: 0.30)
            moltenCore(text, blur: 1.0, opacity: 0.44)

            if animated {
                GlyphFireParticles()
                    .opacity(0.5)
            }
        }
    }

    private func moltenCore(_ text: String, blur: CGFloat, opacity: Double) -> some View {
        amountLabel(text, style: AnyShapeStyle(coreGradient))
            .blur(radius: blur)
            .opacity(opacity)
    }

    private var coreGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0xFFFFE8), location: 0.10),
                .init(color: Color(hex: 0xFFE68E), location: 0.32),
                .init(color: Color(hex: 0xFFC040), location: 0.55),
                .init(color: Color(hex: 0xFF9422), location: 0.75),
                .init(color: Color(hex: 0xFF6A10), location: 0.90),
                .init(color: Color(hex: 0xFF4A04), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func symbolLabel(_ style: AnyShapeStyle) -> some View {
        Text(symbol)
            .font(AppFont.geist(20, .semibold))
            .foregroundStyle(style)
    }

    private func amountLabel(_ text: String, style: AnyShapeStyle) -> some View {
        Text(text)
            .font(AppFont.numbers(46, .semibold))
            .tracking(-1.4)
            .foregroundStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
    }
}

/// The flowing fire inside the glyphs: an ember background with two layers of
/// upward-drifting flame streaks and a handful of sparks. Streaks are seeded
/// across the full height of the label and wrap around, so the whole digit is
/// alight at every moment instead of only its base.
private struct FlameBody: View {
    let time: Double
    let animated: Bool

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: 0x5A1002), location: 0.0),
                        .init(color: Color(hex: 0xA32605), location: 0.30),
                        .init(color: Color(hex: 0xD94A08), location: 0.62),
                        .init(color: Color(hex: 0x8A1C04), location: 0.84),
                        .init(color: Color(hex: 0x4A0C02), location: 1.0)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            var broad = context
            broad.blendMode = .plusLighter
            broad.addFilter(.blur(radius: 4.5))
            drawStreaks(
                &broad,
                size: size,
                count: 20,
                minWidth: 0.030,
                maxWidth: 0.080,
                minAlpha: 0.18,
                maxAlpha: 0.38,
                minSpeed: 0.26,
                maxSpeed: 0.50,
                salt: 3.1
            )

            var fine = context
            fine.blendMode = .plusLighter
            fine.addFilter(.blur(radius: 1.4))
            drawStreaks(
                &fine,
                size: size,
                count: 46,
                minWidth: 0.007,
                maxWidth: 0.024,
                minAlpha: 0.28,
                maxAlpha: 0.58,
                minSpeed: 0.50,
                maxSpeed: 0.95,
                salt: 9.4
            )

            var sparks = context
            sparks.blendMode = .plusLighter
            sparks.addFilter(.blur(radius: 0.7))
            drawSparks(&sparks, size: size)
        }
        .allowsHitTesting(false)
    }

    private func drawStreaks(
        _ context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        minWidth: Double,
        maxWidth: Double,
        minAlpha: Double,
        maxAlpha: Double,
        minSpeed: Double,
        maxSpeed: Double,
        salt: Double
    ) {
        for index in 0..<count {
            let randomX = noise(index, salt + 0.37)
            let randomLength = noise(index, salt + 1.91)
            let randomPhase = noise(index, salt + 2.53)
            let randomSpeed = noise(index, salt + 3.17)
            let randomAlpha = noise(index, salt + 4.61)
            let randomWidth = noise(index, salt + 5.23)
            let randomSway = noise(index, salt + 6.79)
            let randomTint = noise(index, salt + 7.41)

            let speed = minSpeed + (maxSpeed - minSpeed) * randomSpeed
            let progress = animated
                ? (randomPhase + time * speed).truncatingRemainder(dividingBy: 1)
                : (0.18 + 0.64 * randomPhase)

            let width = size.width * CGFloat(minWidth + (maxWidth - minWidth) * randomWidth)
            let length = size.height * CGFloat(0.55 + 0.90 * randomLength)
            let x = size.width * CGFloat(0.02 + 0.96 * randomX)
                + CGFloat(sin(time * (0.6 + randomSway * 0.9) + Double(index) * 1.13))
                    * size.width * 0.022
            let centreY = size.height * CGFloat(1.25 - 1.50 * progress)
            let baseY = centreY + length * 0.55
            let tipY = centreY - length * 0.55
            let sway = CGFloat(sin(time * 1.15 + Double(index) * 2.1 + randomSway * 6.28))
                * width * 1.9

            var path = Path()
            path.move(to: CGPoint(x: x - width * 0.5, y: baseY))
            path.addCurve(
                to: CGPoint(x: x + sway * 0.70, y: tipY),
                control1: CGPoint(x: x - width * 0.62, y: baseY - length * 0.34),
                control2: CGPoint(x: x + sway * 0.30, y: tipY + length * 0.32)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.5, y: baseY),
                control1: CGPoint(x: x + sway * 0.85 + width * 0.50, y: tipY + length * 0.36),
                control2: CGPoint(x: x + width * 0.55, y: baseY - length * 0.30)
            )
            path.closeSubpath()

            let tint = streakColor(randomTint)
            context.opacity = minAlpha + (maxAlpha - minAlpha) * randomAlpha
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: tint.opacity(0.0), location: 0.00),
                        .init(color: tint.opacity(0.55), location: 0.28),
                        .init(color: tint, location: 0.62),
                        .init(color: tint.opacity(0.15), location: 1.00)
                    ]),
                    startPoint: CGPoint(x: x, y: tipY),
                    endPoint: CGPoint(x: x, y: baseY)
                )
            )
        }
    }

    private func drawSparks(_ context: inout GraphicsContext, size: CGSize) {
        for index in 0..<26 {
            let randomX = noise(index, 11.7)
            let randomPhase = noise(index, 12.9)
            let randomSpeed = noise(index, 13.3)
            let randomSize = noise(index, 14.7)

            let speed = 0.35 + 0.55 * randomSpeed
            let progress = animated
                ? (randomPhase + time * speed).truncatingRemainder(dividingBy: 1)
                : randomPhase
            let x = size.width * CGFloat(0.03 + 0.94 * randomX)
                + CGFloat(sin(time * 1.7 + Double(index))) * 3
            let y = size.height * CGFloat(1.15 - 1.45 * progress)
            let radius = size.height * CGFloat(0.014 + 0.024 * randomSize)

            context.opacity = 0.35 + 0.45 * randomSize
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(Color(hex: 0xFFF3C8))
            )
        }
    }

    private func streakColor(_ seed: Double) -> Color {
        switch seed {
        case 0.86...: return Color(hex: 0xFFFFE4)
        case 0.58...: return Color(hex: 0xFFC838)
        default: return Color(hex: 0xFF7E0A)
        }
    }

    private func noise(_ index: Int, _ salt: Double) -> Double {
        let value = sin(Double(index) * 127.1 + salt * 311.7) * 43_758.5453
        return value - floor(value)
    }
}

/// Sparse embers that drift up through the glyph interiors, clipped by the text
/// mask so they never float behind the number.
private struct GlyphFireParticles: View {
    @State private var system = GlyphFire.makeSystem()

    var body: some View {
        VortexView(system, targetFrameRate: 30) {
            FlameParticleShape()
                .fill(.white)
                .frame(width: 20, height: 30)
                .blur(radius: 2.4)
                .tag("flame")

            Circle()
                .fill(.white)
                .frame(width: 5)
                .blur(radius: 1.2)
                .tag("ember")
        }
    }
}

private enum GlyphFire {
    static func makeSystem() -> VortexSystem {
        let system = VortexSystem.fire.makeUniqueCopy()
        system.tags = ["flame", "ember", "ember"]
        system.position = [0.5, 0.5]
        system.shape = .box(width: 0.94, height: 0.84)
        system.birthRate = 70
        system.speed = 0.26
        system.speedVariation = 0.18
        system.angle = .degrees(0)
        system.angleRange = .degrees(20)
        system.lifespan = 0.68
        system.lifespanVariation = 0.26
        system.colors = .ramp(
            color(0xFFFFE0),
            color(0xFFC850),
            color(0xFF7A10),
            color(0xC22400).opacity(0.35),
            color(0x7A0A00).opacity(0)
        )
        system.size = 0.34
        system.sizeVariation = 0.35
        system.sizeMultiplierAtDeath = 0.15
        system.angularSpeed = [0, 0, 0.2]
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
