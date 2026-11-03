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

        let image = NSImage(
            systemSymbolName: "yensign.circle.fill",
            accessibilityDescription: "进账"
        )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("进账计薪")
        button.toolTip = "进账 · 点击查看实时收入"
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 392, height: 608)
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
        let title = "¥\(Fmt.money(snapshot.total))"

        if title != lastTitle {
            button.title = title
            lastTitle = title
        }

        button.toolTip = "进账 · \(snapshot.phase.title) · ¥\(Fmt.money(snapshot.total))"
        button.setAccessibilityValue("\(snapshot.phase.title)，¥\(Fmt.money(snapshot.total))")
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

        let openItem = NSMenuItem(title: "打开进账", action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(title: "重置本次计薪…", action: #selector(resetSession), keyEquivalent: "")
        resetItem.target = self
        resetItem.isEnabled = model.session.hasRecordedTime
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出进账", action: #selector(quitApp), keyEquivalent: "q")
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
        alert.messageText = "重置本次计薪？"
        alert.informativeText = "当前累计的 ¥\(Fmt.money(model.snapshot.total)) 将清零，且无法恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "重置")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            model.resetSession()
            refresh()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }
}
