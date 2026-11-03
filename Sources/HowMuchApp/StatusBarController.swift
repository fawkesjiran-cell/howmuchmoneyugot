import AppKit
import HowMuchCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let hostingController: NSHostingController<AnyView>
    private var refreshTimer: Timer?
    private var lastTitle: String = ""
    private var lastCurrency: CurrencyUnit?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.hostingController = NSHostingController(
            rootView: AnyView(PopoverView().environmentObject(model))
        )
        super.init()

        configureStatusItem()
        configurePopover()
        startRefreshTimer()
        refresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public

    func showPopover() {
        guard let button = statusItem.button else { return }
        guard !popover.isShown else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
        popover.contentViewController?.view.window?.makeKey()
    }

    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        statusItem.button?.highlight(false)
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = statusImage(for: model.currency)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel(model.t(.statusAccessibilityLabel))
        button.toolTip = AppMetadata.displayName
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 392, height: 456)
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func startRefreshTimer() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let snapshot = model.snapshot
        let title = model.money(snapshot.total)

        if lastCurrency != model.currency {
            button.image = statusImage(for: model.currency)
            lastCurrency = model.currency
            lastTitle = ""
        }

        if title != lastTitle {
            button.title = title
            lastTitle = title
        }

        button.setAccessibilityLabel(model.t(.statusAccessibilityLabel))
        button.toolTip = model.t(
            .statusTooltip,
            AppMetadata.displayName,
            model.phaseTitle(snapshot.phase),
            model.money(snapshot.total)
        )
        button.setAccessibilityValue(
            model.t(
                .statusAccessibilityValue,
                model.phaseTitle(snapshot.phase),
                model.money(snapshot.total)
            )
        )
    }

    // MARK: - Interaction

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            togglePopover()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: model.t(.openApp, AppMetadata.displayName),
            action: #selector(openPanel),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(
            title: model.t(.resetThisSession) + "…",
            action: #selector(resetSession),
            keyEquivalent: ""
        )
        resetItem.target = self
        resetItem.isEnabled = model.session.hasRecordedTime
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: model.t(.quitApp, AppMetadata.displayName),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 3),
            in: button
        )
    }

    @objc private func openPanel() {
        showPopover()
    }

    @objc private func resetSession() {
        let alert = NSAlert()
        alert.messageText = model.t(.resetConfirmTitle)
        alert.informativeText = model.t(
            .resetConfirmMessage,
            model.money(model.snapshot.total)
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: model.t(.reset))
        alert.addButton(withTitle: model.t(.cancel))

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            model.resetSession()
            refresh()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func statusImage(for currency: CurrencyUnit) -> NSImage? {
        let image = NSImage(
            systemSymbolName: iconName(for: currency),
            accessibilityDescription: AppMetadata.displayName
        ) ?? NSImage(
            systemSymbolName: "creditcard.circle.fill",
            accessibilityDescription: AppMetadata.displayName
        )
        image?.isTemplate = true
        return image
    }

    private func iconName(for currency: CurrencyUnit) -> String {
        switch currency {
        case .cny, .jpy: return "yensign.circle.fill"
        case .usd, .hkd, .sgd: return "dollarsign.circle.fill"
        case .eur: return "eurosign.circle.fill"
        case .gbp: return "sterlingsign.circle.fill"
        case .krw: return "wonsign.circle.fill"
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }
}
