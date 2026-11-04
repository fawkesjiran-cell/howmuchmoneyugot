import AppKit
import SwiftUI

/// Pine Ledger tokens. Flat surfaces, 1px hairlines, pine for earned money,
/// ember for overtime, red only for destructive actions.
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

    static let canvas = dynamic(light: 0xF3F6F4, dark: 0x091310)
    static let canvasDeep = canvas
    static let sunken = dynamic(light: 0xE8EFEA, dark: 0x060E0B)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x111E18)
    static let surfaceStrong = surface
    static let surfaceMuted = dynamic(light: 0xEEF3EF, dark: 0x0D1813)
    static let line = dynamic(light: 0xDCE5DF, dark: 0x263A30)
    static let lineStrong = dynamic(light: 0xC6D3CA, dark: 0x345044)

    static let ink = dynamic(light: 0x0E1F18, dark: 0xEAF2ED)
    static let secondary = dynamic(light: 0x55685E, dark: 0x9FB3A7)
    static let tertiary = dynamic(light: 0x5F746A, dark: 0x7C9185)
    static let muted = secondary
    static let faint = tertiary

    static let primary = dynamic(light: 0x146B4A, dark: 0x5BD6A0)
    static let primaryHover = dynamic(light: 0x0D5238, dark: 0x86E9BC)
    static let primarySoft = dynamic(light: 0xDCEFE4, dark: 0x123528)
    static let onPrimary = dynamic(light: 0xFFFFFF, dark: 0x06231A)

    static let ember = dynamic(light: 0xA5480A, dark: 0xF0A868)
    static let emberSoft = dynamic(light: 0xFBEBDC, dark: 0x2A1B0F)
    static let onEmber = dynamic(light: 0xFFFFFF, dark: 0x1A0F06)

    static let danger = dynamic(light: 0xB3261E, dark: 0xFF8177)
    static let dangerSoft = dynamic(light: 0xFBEAE8, dark: 0x2B1513)

    static let shadow = Color.clear

    // Compatibility aliases retained for the rest of the app.
    static let normal = primary
    static let green = primary
    static let accent = primary
    static let accentDeep = primary
    static let gold = ember
    static let goldDeep = ember
    static let buttonInk = ink
    static let buttonInkText = onPrimary
    static let heroTop = canvas
    static let heroBottom = canvas
    static let heroText = ink
    static let heroMuted = secondary
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
        Palette.canvas.ignoresSafeArea()
    }
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var fill: Color = Palette.surface

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.8)
            )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 12, fill: Color = Palette.surface) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius, fill: fill))
    }
}

struct SmallCapsLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Palette.secondary)
    }
}
