import CoreText
import SwiftUI

/// Geist is the typeface used by the Signal Ledger mock. It is bundled with the
/// app and registered lazily so both the packaged app and the capture harness
/// use the same metrics. Chinese copy falls back to the system CJK face.
///
/// The app bundle name contains a `?`. CoreText happily reports a successful
/// registration for such a URL but exposes a seven-glyph placeholder, so the
/// font is copied to a plain temporary path before registration.
enum AppFont {
    private static var registered = false

    static func prepare() {
        registerIfNeeded()
    }

    static func geist(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        registerIfNeeded()
        return Font.custom(faceName(for: weight), size: size)
    }

    static func numbers(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        geist(size, weight).monospacedDigit()
    }

    private static func faceName(for weight: Font.Weight) -> String {
        if weight == .semibold { return "Geist-SemiBold" }
        if weight == .medium { return "Geist-Medium" }
        if weight == .bold { return "Geist-Bold" }
        if weight == .light { return "Geist-Light" }
        return "Geist-Regular"
    }

    private static func registerIfNeeded() {
        guard !registered else { return }
        registered = true

        guard let source = fontSourceURL() else { return }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HowMuchFonts", isDirectory: true)
        let destination = directory.appendingPathComponent("Geist.ttf")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Data(contentsOf: source)
            try data.write(to: destination, options: .atomic)
        } catch {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(destination as CFURL, .process, &error)
    }

    private static func fontSourceURL() -> URL? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Fonts/Geist[wght].ttf"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Fonts/Geist[wght].ttf"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Fonts/Geist[wght].ttf")
        ]

        return candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}
