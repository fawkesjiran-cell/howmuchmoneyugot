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
        model.language = language
        model.currency = currency
        model.settings = PaySettings(
            monthlySalary: 22_000,
            workDaysPerMonth: 22,
            hoursPerDay: 8,
            overtimeHourlyRate: 187.5
        )
        model.ledger = EarningsLedger(completedEarnings: 1_280.40, completedSessions: 4)
        let args = ProcessInfo.processInfo.arguments
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
