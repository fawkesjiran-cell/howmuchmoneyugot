import AppKit
import SwiftUI

enum Palette {
    private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(
                hex: isDark ? dark : light,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }

    static let canvas = dynamic(light: 0xF6F2E9, dark: 0x141916)
    static let canvasDeep = dynamic(light: 0xEFE9DD, dark: 0x101411)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.76, darkAlpha: 0.055)
    static let surfaceStrong = dynamic(light: 0xFFFFFF, dark: 0x242C27, lightAlpha: 0.94, darkAlpha: 0.96)
    static let surfaceMuted = dynamic(light: 0xEDE7DA, dark: 0x202722, lightAlpha: 0.8, darkAlpha: 0.8)
    static let line = dynamic(light: 0xE0D9CB, dark: 0x323C35, lightAlpha: 0.9, darkAlpha: 0.8)

    static let ink = dynamic(light: 0x17211B, dark: 0xF3EEE4)
    static let secondary = dynamic(light: 0x6E7871, dark: 0xA4AEA7)
    static let tertiary = dynamic(light: 0x969E98, dark: 0x7D8880)

    static let normal = dynamic(light: 0x157A53, dark: 0x4AC48C)
    static let normalDeep = dynamic(light: 0x0B4A34, dark: 0x0E5C40)
    static let normalSoft = dynamic(light: 0xE2F0E8, dark: 0x163C2D, lightAlpha: 0.9, darkAlpha: 0.8)
    static let gold = dynamic(light: 0xCB821E, dark: 0xF0B15A)
    static let goldDeep = dynamic(light: 0xA9660D, dark: 0xD8953F)
    static let goldSoft = dynamic(light: 0xF8ECD7, dark: 0x3B2C16, lightAlpha: 0.95, darkAlpha: 0.8)
    static let danger = dynamic(light: 0xB0473D, dark: 0xE38A80)

    static let heroTop = dynamic(light: 0x0A3F2D, dark: 0x062E21)
    static let heroBottom = dynamic(light: 0x116849, dark: 0x0A5038)
    static let heroLine = Color(hex: 0xF5EEDF).opacity(0.10)
    static let heroText = Color(hex: 0xFBF6EA)
    static let heroMuted = Color(hex: 0xFBF6EA).opacity(0.60)
    static let heroSubtle = Color(hex: 0xFBF6EA).opacity(0.16)

    static let buttonInk = dynamic(light: 0x1B261F, dark: 0xEAE4D8)
    static let buttonInkText = dynamic(light: 0xF8F3E7, dark: 0x1A211D)

    static let shadow = Color.black.opacity(0.16)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Palette.canvas
            RadialGradient(
                colors: [Palette.normal.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [Palette.gold.opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 330
            )
            LinearGradient(
                colors: [.clear, Palette.canvasDeep.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.8)
            )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

struct SmallCapsLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(Palette.secondary)
    }
}
