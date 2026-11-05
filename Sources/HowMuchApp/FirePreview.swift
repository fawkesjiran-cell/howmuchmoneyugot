import AppKit
import HowMuchCore
import SwiftUI

@MainActor
enum FirePreview {
    static func capture(to path: String, language: AppLanguage, currency: CurrencyUnit) {
        AppFont.prepare()
        let suite = "jinzhang.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = AppModel(defaults: defaults)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--dark") {
            model.theme = .dark
        } else if args.contains("--light") {
            model.theme = .light
        }
        model.language = language
        model.currency = currency
        model.setPanelPresented(true)
        if args.contains("--bigmac")
            || args.contains("--bigmac-drop")
            || args.contains("--bigmac-count") {
            model.bigMacCounterEnabled = true
        }
        model.settings = PaySettings(
            monthlySalary: 22_000,
            workDaysPerMonth: 22,
            hoursPerDay: 8,
            overtimeHourlyRate: 187.5
        )
        if args.contains("--salary-preview") {
            model.updateMonthlySalary(30_000)
        }
        if args.contains("--check-updates") {
            model.checkForUpdatesEnabled = true
            model.checkForUpdatesManually()
        }
        if args.contains("--auto-update-preview") {
            model.autoUpdateEnabled = true
        }
        model.ledger = EarningsLedger(completedEarnings: 1_280.40, completedSessions: 4)
        let modeIndex = args.firstIndex(of: "--capture-mode")
        let mode = modeIndex.map { args[$0 + 1] } ?? "overtime"
        let now = Date()
        switch mode {
        case "normal":
            model.session = WorkSession(
                phase: .working,
                normalStartedAt: now.addingTimeInterval(-(3 * 3_600 + 12 * 60 + 24))
            )
        case "idle":
            model.session = .idle
        case "clockedout":
            model.session = WorkSession(
                phase: .clockedOut,
                normalStartedAt: now.addingTimeInterval(-(8 * 3_600)),
                normalEndedAt: now.addingTimeInterval(-(1 * 3_600))
            )
        case "finished":
            model.session = WorkSession(
                phase: .finished,
                normalStartedAt: now.addingTimeInterval(-(9 * 3_600)),
                normalEndedAt: now.addingTimeInterval(-(2 * 3_600)),
                overtimeStartedAt: now.addingTimeInterval(-(2 * 3_600)),
                overtimeEndedAt: now.addingTimeInterval(-(30 * 60))
            )
        default:
            model.session = WorkSession(
                phase: .overtime,
                normalStartedAt: now.addingTimeInterval(-(5 * 3_600)),
                normalEndedAt: now.addingTimeInterval(-(2 * 3_600)),
                overtimeStartedAt: now.addingTimeInterval(-(1.5 * 3_600))
            )
        }

        // Debug-only: arrange for the second Big Mac to land shortly after the
        // preview appears so the drop animation can be inspected in a still.
        if args.contains("--bigmac-drop") {
            let price = BigMacIndex.price(for: currency).localPrice
            let rate = model.settings.normalPerSecondRate
            if price > 0, rate > 0 {
                let elapsed = price * 2 / rate - 1.1
                if elapsed > 0 {
                    model.session = WorkSession(
                        phase: .working,
                        normalStartedAt: now.addingTimeInterval(-elapsed)
                    )
                }
            }
        }

        // Debug-only: pin the preview to a specific Big Mac count (for checking
        // dense 200-burger layouts without waiting for a giant salary).
        if let index = args.firstIndex(of: "--bigmac-count"),
           args.indices.contains(index + 1),
           let target = Int(args[index + 1]),
           target > 0 {
            let price = BigMacIndex.price(for: currency).localPrice
            let rate = model.settings.normalPerSecondRate
            if price > 0, rate > 0 {
                let elapsed = price * Double(target) / rate
                if elapsed > 0 {
                    model.session = WorkSession(
                        phase: .working,
                        normalStartedAt: now.addingTimeInterval(-elapsed)
                    )
                }
            }
        }

        let content = AnyView(
            ZStack {
                AppBackground()
                if mode == "settings" {
                    SettingsView(close: {}).environmentObject(model)
                } else {
                    DashboardView(openSettings: {}).environmentObject(model)
                }
            }
            .frame(width: 392, height: 320)
            .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        )
        let view = NSHostingView(rootView: content)
        view.frame = NSRect(x: 0, y: 0, width: 392, height: 320)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 392, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.colorSpace = .sRGB
        window.setFrameOrigin(NSPoint(x: 120, y: 120))
        window.orderFrontRegardless()
        window.makeKey()

        let captureDelay: TimeInterval = {
            guard let index = args.firstIndex(of: "--capture-delay"),
                  args.indices.contains(index + 1),
                  let value = Double(args[index + 1]) else { return 1.5 }
            return max(0.2, value)
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) {
            view.layoutSubtreeIfNeeded()

            if ProcessInfo.processInfo.arguments.contains("--capture-scroll"),
               let scrollView = firstScrollView(in: view) {
                scrollView.layoutSubtreeIfNeeded()
                let documentHeight = scrollView.documentView?.bounds.height ?? 0
                let visibleHeight = scrollView.contentView.bounds.height
                let bottom = max(0, documentHeight - visibleHeight)
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                view.layoutSubtreeIfNeeded()
            }

            view.displayIfNeeded()

            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                NSApp.terminate(nil)
                return
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            let srgb = rep.converting(to: .sRGB, renderingIntent: .relativeColorimetric) ?? rep
            if let data = srgb.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            window.orderOut(nil)
            NSApp.terminate(nil)
        }
    }

    private static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) {
                return found
            }
        }
        return nil
    }
}
