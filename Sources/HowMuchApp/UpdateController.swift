import AppKit
import Combine
import CryptoKit
import Foundation
import HowMuchCore

/// Lightweight updater for the native macOS app.
///
/// The release list and assets come from GitHub Releases. Automatic installs
/// verify the published SHA-256 checksum, the app bundle version/identifier and
/// the code signature before a small detached helper replaces the current app
/// after it quits. If the app is translocated, read-only, or verification fails,
/// nothing is replaced.
@MainActor
final class UpdateController: ObservableObject {
    enum Failure: Error, Equatable {
        case network
        case missingAsset
        case checksum
        case unsafeInstallLocation
        case invalidPackage
        case install
    }

    enum Status: Equatable {
        case disabled
        case idle
        case checking
        case upToDate(String)
        case available(String)
        case downloading(String)
        case preparing(String)
        case installing(String)
        case failed(Failure)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastChecked: Date?

    let currentVersion: String

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private struct PendingUpdate {
        let release: GitHubRelease
        let latest: AppVersion
        let asset: GitHubAsset
    }

    private let releaseAPI = URL(
        string: "https://api.github.com/repos/fawkesjiran-cell/howmuchmoneyugot/releases/latest"
    )!
    private let checksumsAssetName = "SHA256SUMS.txt"
    private let currentBundleIdentifier: String?
    private let session: URLSession
    private let fileManager = FileManager.default
    private let updateRoot: URL
    private let logURL: URL
    private var task: Task<Void, Never>?
    private var pending: PendingUpdate?

    init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.5.5"
        currentVersion = version
        currentBundleIdentifier = Bundle.main.bundleIdentifier

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 180
        configuration.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "HowMuch/\(version)"
        ]
        session = URLSession(configuration: configuration)

        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        updateRoot = support
            .appendingPathComponent("HowMuch", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)

        let logs = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        logURL = logs.appendingPathComponent("Logs/HowMuchUpdate.log")
    }

    // MARK: - Public actions

    /// Checks the latest GitHub release. When `autoUpdate` is true and a newer
    /// Swift macOS release exists, downloads and installs it automatically.
    func check(autoUpdate: Bool) {
        if case .installing = status { return }

        task?.cancel()
        pending = nil
        status = .checking
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performCheck(autoUpdate: autoUpdate)
            self.task = nil
        }
    }

    /// Downloads and installs the update discovered by the last check.
    func installAvailableUpdate() {
        guard task == nil, let pending else { return }

        status = .downloading(pending.latest.description)
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.install(pending)
            } catch {
                if !Task.isCancelled {
                    self.status = .failed(Self.failure(from: error))
                }
            }
            self.task = nil
        }
    }

    func disable() {
        if case .installing = status { return }
        task?.cancel()
        task = nil
        pending = nil
        status = .disabled
    }

    // MARK: - Checking

    private func performCheck(autoUpdate: Bool) async {
        do {
            let release = try await fetchLatestRelease()
            guard !Task.isCancelled else { return }
            lastChecked = Date()

            guard let latest = AppVersion(release.tagName) else {
                throw Failure.invalidPackage
            }
            guard let current = AppVersion(currentVersion), current < latest else {
                pending = nil
                status = .upToDate(currentVersion)
                return
            }

            guard let assetName = UpdateCatalog.swiftMacOSAssetName(
                from: release.assets.map(\.name)
            ), let asset = release.assets.first(where: { $0.name == assetName }) else {
                throw Failure.missingAsset
            }

            let pendingUpdate = PendingUpdate(release: release, latest: latest, asset: asset)
            pending = pendingUpdate

            if autoUpdate {
                try await install(pendingUpdate)
            } else {
                status = .available(latest.description)
            }
        } catch {
            guard !Task.isCancelled else { return }
            status = .failed(Self.failure(from: error))
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: releaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("HowMuch/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw Failure.network
            }
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.network
        }
    }

    // MARK: - Downloading and installing

    private func install(_ update: PendingUpdate) async throws {
        try ensureSafeInstallLocation()
        try validateRemoteURL(update.asset.browserDownloadURL)

        guard let checksums = update.release.assets.first(where: { $0.name == checksumsAssetName }) else {
            throw Failure.checksum
        }
        try validateRemoteURL(checksums.browserDownloadURL)

        status = .downloading(update.latest.description)
        let checksumText = try await downloadText(checksums.browserDownloadURL)
        guard let expectedHash = UpdateCatalog.checksum(
            forAssetNamed: update.asset.name,
            in: checksumText
        ) else {
            throw Failure.checksum
        }

        let installDirectory = updateRoot.appendingPathComponent(
            update.latest.description,
            isDirectory: true
        )
        try? fileManager.removeItem(at: installDirectory)
        try fileManager.createDirectory(
            at: installDirectory,
            withIntermediateDirectories: true
        )

        let zipURL = installDirectory.appendingPathComponent("update.zip")
        try await downloadFile(update.asset.browserDownloadURL, to: zipURL)
        guard try sha256(of: zipURL) == expectedHash else {
            throw Failure.checksum
        }

        status = .preparing(update.latest.description)
        let extractDirectory = installDirectory.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        let unzipStatus = try await runProcess(
            "/usr/bin/ditto",
            ["-x", "-k", zipURL.path, extractDirectory.path]
        )
        guard unzipStatus == 0, let newApp = findApp(in: extractDirectory) else {
            throw Failure.invalidPackage
        }
        try verify(app: newApp, latest: update.latest)
        let signatureStatus = try await runProcess(
            "/usr/bin/codesign",
            ["--verify", "--deep", "--strict", newApp.path]
        )
        guard signatureStatus == 0 else {
            throw Failure.invalidPackage
        }

        let script = try makeInstallerScript()
        let destination = Bundle.main.bundleURL
        status = .installing(update.latest.description)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            script.path,
            destination.path,
            newApp.path,
            String(ProcessInfo.processInfo.processIdentifier),
            logURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw Failure.install
        }

        // Give the detached helper a moment to start before the app exits.
        try? await Task.sleep(nanoseconds: 350_000_000)
        NSApp.terminate(nil)
    }

    private func ensureSafeInstallLocation() throws {
        let destination = Bundle.main.bundleURL
        guard destination.pathExtension == "app",
              currentBundleIdentifier != nil else {
            throw Failure.unsafeInstallLocation
        }
        guard !destination.path.contains("/AppTranslocation/") else {
            throw Failure.unsafeInstallLocation
        }
        guard !destination.path.hasPrefix("/Volumes/") else {
            throw Failure.unsafeInstallLocation
        }
        let parent = destination.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parent.path) else {
            throw Failure.unsafeInstallLocation
        }
    }

    private func verify(app: URL, latest: AppVersion) throws {
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String,
              identifier == currentBundleIdentifier,
              let versionString = plist["CFBundleShortVersionString"] as? String,
              let version = AppVersion(versionString),
              version >= latest else {
            throw Failure.invalidPackage
        }
    }

    private func makeInstallerScript() throws -> URL {
        try fileManager.createDirectory(at: updateRoot, withIntermediateDirectories: true)
        if let logsDirectory = logURL.deletingLastPathComponent() as URL? {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        let scriptURL = updateRoot.appendingPathComponent("install-\(UUID().uuidString).sh")
        let script = #"""
        #!/bin/bash
        set -u
        DEST="$1"
        SRC="$2"
        PID="$3"
        LOG="$4"
        BACKUP="${DEST}.backup.$$"

        exec >>"$LOG" 2>&1
        echo "--- $(date) starting update"
        echo "waiting for pid $PID"

        for _ in {1..600}; do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.2
        done
        if kill -0 "$PID" 2>/dev/null; then
            echo "app did not exit"
            exit 1
        fi

        if ! mv "$DEST" "$BACKUP"; then
            echo "could not move current app"
            /usr/bin/open "$DEST"
            exit 1
        fi

        if /usr/bin/ditto "$SRC" "$DEST"; then
            /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
            rm -rf "$BACKUP"
            /usr/bin/open "$DEST"
            echo "update complete"
            rm -rf "$(dirname "$SRC")" 2>/dev/null || true
            exit 0
        fi

        echo "copy failed; restoring current app"
        rm -rf "$DEST"
        mv "$BACKUP" "$DEST"
        /usr/bin/open "$DEST"
        exit 1
        """#
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
        return scriptURL
    }

    private func findApp(in directory: URL) -> URL? {
        if let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ), let app = items.first(where: { $0.pathExtension == "app" }) {
            return app
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else { return nil }

        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    private func downloadText(_ url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let text = String(data: data, encoding: .utf8) else {
            throw Failure.network
        }
        return text
    }

    private func downloadFile(_ url: URL, to destination: URL) async throws {
        let (temporary, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw Failure.network
        }
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: temporary, to: destination)
    }

    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func runProcess(_ executable: String, _ arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    continuation.resume(throwing: Failure.install)
                }
            }
        }
    }

    private func validateRemoteURL(_ url: URL) throws {
        guard url.scheme == "https",
              let host = url.host,
              host == "github.com"
                || host.hasSuffix(".github.com")
                || host.hasSuffix(".githubusercontent.com") else {
            throw Failure.network
        }
    }

    private static func failure(from error: Error) -> Failure {
        if let failure = error as? Failure { return failure }
        return .network
    }
}
