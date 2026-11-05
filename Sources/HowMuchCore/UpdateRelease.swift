import Foundation

/// Numeric app version used by the GitHub Releases updater. Tags such as
/// `v1.5.10` compare numerically so 1.5.10 is newer than 1.5.9.
public struct AppVersion: Comparable, Equatable, Hashable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?(_ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }
        if let cut = value.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            value = String(value[..<cut])
        }

        let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
        guard let first = pieces.first,
              let major = Int(first),
              major >= 0 else { return nil }

        let minor = pieces.count > 1 ? Int(pieces[1]) : 0
        let patch = pieces.count > 2 ? Int(pieces[2]) : 0
        guard let minor, let patch, minor >= 0, patch >= 0 else { return nil }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

/// Pure helpers shared by the app-level updater and core checks.
public enum UpdateCatalog {
    public static func swiftMacOSAssetName(from names: [String]) -> String? {
        names.first { name in
            name.localizedCaseInsensitiveContains("macOS-Swift")
                && name.lowercased().hasSuffix(".zip")
        }
    }

    public static func checksum(forAssetNamed assetName: String, in text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let pieces = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard pieces.count >= 2 else { continue }
            let hash = String(pieces[0]).lowercased()
            let name = pieces.dropFirst().joined(separator: " ")
            if name == assetName, isSHA256(hash) {
                return hash
            }
        }
        return nil
    }

    public static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.allSatisfy { character in
            character.isHexDigit
        }
    }
}
