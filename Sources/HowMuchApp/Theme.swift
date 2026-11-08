import AppKit
import SwiftUI

/// How the app chooses its appearance. The UI exposes one compact button that
/// cycles through system → light → dark, so the choice is always one click away.
enum ThemePreference: String, CaseIterable {
    case system
    case light
    case dark

    var next: ThemePreference {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }

    var icon: ReiconAsset {
        switch self {
        case .system: return .darkLight
        case .light: return .sun
        case .dark: return .moon
        }
    }

    var titleKey: LKey {
        switch self {
        case .system: return .appearanceSystem
        case .light: return .appearanceLight
        case .dark: return .appearanceDark
        }
    }
}

/// Signal Ledger tokens. Flat surfaces, 1px hairlines, crimson for earned money,
/// yellow for overtime, and a deeper crimson only for destructive actions.
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

    static let canvas = dynamic(light: 0xFFFFFF, dark: 0x1C1416)
    static let canvasDeep = canvas
    static let sunken = dynamic(light: 0xF1DDDF, dark: 0x120D0F)
    static let surface = dynamic(light: 0xF1DDDF, dark: 0x2A2022)
    static let surfaceStrong = surface
    /// Inputs and other wells sit on top of a pink block, so keep them white.
    static let field = dynamic(light: 0xFFFFFF, dark: 0x1C1416)
    static let surfaceMuted = dynamic(light: 0xF1DDDF, dark: 0x33272A)
    static let line = dynamic(light: 0xE3BEC5, dark: 0x453739)
    static let lineStrong = dynamic(light: 0xD1A0A8, dark: 0x5D4B4F)

    static let ink = dynamic(light: 0x2B0B12, dark: 0xF8F1F2)
    static let secondary = dynamic(light: 0x6D3A45, dark: 0xCDB9BD)
    static let tertiary = dynamic(light: 0x80505A, dark: 0xA68F94)
    static let muted = secondary
    static let faint = tertiary

    static let primary = dynamic(light: 0xE72D48, dark: 0xFF6579)
    static let primaryHover = dynamic(light: 0xC91F39, dark: 0xFF8B9A)
    static let primarySoft = dynamic(light: 0xF1DDDF, dark: 0x3A2227)
    static let onPrimary = dynamic(light: 0xFFFFFF, dark: 0x2B0B12)

    /// Gold is the legible text tone for the yellow highlight on light
    /// surfaces; the exact FFE76F is used for filled surfaces and the fire.
    static let ember = dynamic(light: 0x8A5A00, dark: 0xFFE76F)
    static let emberFill = dynamic(light: 0xFFE76F, dark: 0xFFE76F)
    static let emberSoft = dynamic(light: 0xFFF3B0, dark: 0x3A2F0F)
    static let onEmber = dynamic(light: 0x2B0B12, dark: 0x2B0B12)

    static let danger = dynamic(light: 0xB3122C, dark: 0xFF8A9A)
    static let dangerSoft = dynamic(light: 0xF1DDDF, dark: 0x3A1D22)

    static let shadow = Color.clear

    // Compatibility aliases retained for the rest of the app.
    static let normal = primary
    static let green = primary
    static let accent = primary
    static let accentDeep = primary
    static let gold = emberFill
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
