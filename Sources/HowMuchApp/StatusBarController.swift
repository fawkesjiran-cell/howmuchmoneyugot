import AppKit
import HowMuchCore
import QuartzCore
import SwiftUI

/// A tiny emoji-only view that slides across the status item when a new Big Mac
/// is earned. It never participates in hit testing, so the menu bar item keeps
/// its normal click target while the burger passes over it.
private final class BurgerFlashView: NSView {
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text = "🍔" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15)
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: 0,
            y: max(0, (bounds.height - size.height) / 2),
            width: bounds.width,
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }
}

/// Clicking the first time in a fresh popover window should register, even when
/// the app was just activated; AppKit otherwise swallows that click.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class FirstMouseHostingController<Content: View>: NSViewController {
    init(rootView: Content) {
        super.init(nibName: nil, bundle: nil)
        view = FirstMouseHostingView(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let hostingController: NSViewController
    private var refreshTimer: Timer?
    private var isMenuTracking = false
    private var lastTitle: String = ""
    private var lastCurrency: CurrencyUnit?
    private var lastBigMacCount: Int?
    private var burgerFlashView: BurgerFlashView?
    private var burgerFlashTimer: Timer?
    private var burgerFlashToken = 0
    private var burgerFlashStartedAt: CFTimeInterval = 0
    private var burgerFlashStartX: CGFloat = 0
    private var burgerFlashEndX: CGFloat = 0

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.hostingController = FirstMouseHostingController(
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
        burgerFlashTimer?.invalidate()
    }

    // MARK: - Public

    func showPopover() {
        guard let button = statusItem.button else { return }
        guard !popover.isShown else { return }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        model.setPanelPresented(true)
        applyAppearance(NSApp.appearance)
        button.highlight(true)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// NSPopover keeps the appearance it resolved when its window was created.
    /// Re-apply the app appearance explicitly so a theme click updates an open
    /// panel instead of only the next launch.
    func applyAppearance(_ appearance: NSAppearance?) {
        popover.appearance = appearance
        hostingController.view.appearance = appearance
        hostingController.view.window?.appearance = appearance
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
        model.setPanelPresented(false)
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
        popover.contentSize = NSSize(width: 392, height: 320)
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
        // While the context menu is tracking, a status item title change would
        // move the anchor and make AppKit dismiss/reshape the open menu.
        guard !isMenuTracking, let button = statusItem.button else { return }
        let snapshot = model.snapshot
        let allTimeTotal = model.money(model.totalEarned)
        let title = allTimeTotal

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
        let tooltip = model.t(
            .statusTooltip,
            AppMetadata.displayName,
            model.phaseTitle(snapshot.phase),
            allTimeTotal
        )
        button.toolTip = model.bigMacCounterEnabled
            ? tooltip + " · " + model.t(.bigMacAccessibility, model.bigMacCount)
            : tooltip
        let accessibilityValue = model.t(
            .statusAccessibilityValue,
            model.phaseTitle(snapshot.phase),
            allTimeTotal
        )
        button.setAccessibilityValue(
            model.bigMacCounterEnabled
                ? accessibilityValue + ", " + model.t(.bigMacAccessibility, model.bigMacCount)
                : accessibilityValue
        )

        refreshBigMacCounter(button: button)
    }

    private func refreshBigMacCounter(button: NSStatusBarButton) {
        guard model.bigMacCounterEnabled else {
            lastBigMacCount = nil
            return
        }

        let count = model.bigMacCount
        guard let previous = lastBigMacCount else {
            lastBigMacCount = count
            return
        }
        lastBigMacCount = count

        guard count > previous else { return }
        flashBigMac(in: button)
    }

    private func flashBigMac(in button: NSStatusBarButton) {
        burgerFlashToken += 1
        let token = burgerFlashToken
        burgerFlashTimer?.invalidate()
        burgerFlashTimer = nil
        burgerFlashView?.removeFromSuperview()
        burgerFlashView = nil

        let height = max(button.bounds.height, 22)
        let width: CGFloat = 22
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let startX = reduceMotion
            ? (button.bounds.width - width) / 2
            : -width - 2
        let endX = reduceMotion ? startX : button.bounds.width + 4
        let flash = BurgerFlashView(
            frame: NSRect(
                x: startX,
                y: 0,
                width: width,
                height: height
            )
        )
        flash.wantsLayer = true
        flash.setAccessibilityElement(false)
        button.addSubview(flash)

        burgerFlashView = flash
        burgerFlashStartX = startX
        burgerFlashEndX = endX
        burgerFlashStartedAt = CACurrentMediaTime()

        // NSView's animator proxy does not animate arbitrary subviews of a
        // status-bar button reliably, so drive this short slide on the main
        // run loop at display-ish cadence instead.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stepBurgerFlash(token: token)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        burgerFlashTimer = timer
    }

    private func stepBurgerFlash(token: Int) {
        guard token == burgerFlashToken else { return }
        guard let flash = burgerFlashView else {
            burgerFlashTimer?.invalidate()
            burgerFlashTimer = nil
            return
        }

        let duration: CFTimeInterval = 0.78
        let elapsed = CACurrentMediaTime() - burgerFlashStartedAt
        let progress = min(max(elapsed / duration, 0), 1)
        let eased: CGFloat
        if progress < 0.5 {
            eased = CGFloat(2 * progress * progress)
        } else {
            eased = CGFloat(1 - pow(-2 * progress + 2, 2) / 2)
        }

        flash.frame.origin.x = burgerFlashStartX
            + (burgerFlashEndX - burgerFlashStartX) * eased

        if elapsed > 0.58 {
            flash.alphaValue = max(0, 1 - (elapsed - 0.58) / 0.20)
        }

        if progress >= 1 {
            burgerFlashTimer?.invalidate()
            burgerFlashTimer = nil
            flash.removeFromSuperview()
            burgerFlashView = nil
        }
    }

    // MARK: - Interaction

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp, .rightMouseDown:
            showContextMenu(from: sender)
        case .leftMouseUp:
            togglePopover()
        default:
            break
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

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

        isMenuTracking = true
        defer {
            isMenuTracking = false
            refresh()
        }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
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
        model.setPanelPresented(false)
        statusItem.button?.highlight(false)
    }
}
