import AppKit
import SwiftUI

/// Bundled Reicon glyphs. The PDFs live in `Resources/Reicon` and are copied
/// into the app bundle by `Scripts/build_app.sh`; see the manifest for the
/// source version and weight of each icon.
enum ReiconAsset: String, CaseIterable {
    case darkLight = "dark-light"
    case sun
    case moon
    case undoCircle = "undo-circle"
    case arrowsRotate = "arrows-rotate"
    case download
    case gear
    case play
    case stop
    case flame
    case check
    case chevronLeft = "chevron-left"
    case chevronDown = "chevron-down"
    case banknote2
    case calendar
    case clock
    case bolt
    case trash2

    private static let images: [String: NSImage] = {
        var images: [String: NSImage] = [:]
        for asset in allCases {
            guard let url = Bundle.main.url(
                forResource: asset.rawValue,
                withExtension: "pdf",
                subdirectory: "Reicon"
            ), let image = NSImage(contentsOf: url) else {
                assertionFailure("Missing Reicon asset: \(asset.rawValue).pdf")
                continue
            }
            image.isTemplate = true
            images[asset.rawValue] = image
        }
        return images
    }()

    var image: NSImage {
        if let image = Self.images[rawValue] {
            return image
        }
        let fallback = NSImage(
            systemSymbolName: "questionmark",
            accessibilityDescription: nil
        ) ?? NSImage(size: NSSize(width: 24, height: 24))
        fallback.isTemplate = true
        return fallback
    }
}

/// A monochrome Reicon glyph that is tinted by the surrounding SwiftUI view.
struct ReiconIcon: View {
    let asset: ReiconAsset
    var size: CGFloat
    var tint: Color

    var body: some View {
        Image(nsImage: asset.image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}
