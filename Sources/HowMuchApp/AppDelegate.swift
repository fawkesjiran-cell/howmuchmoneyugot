import AppKit
import Combine
import HowMuchCore

@main
struct HowMuchMoneyUGotApp {
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusBarController: StatusBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()

        statusBarController = StatusBarController(model: model)

        model.$language
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.installMainMenu()
                }
            }
            .store(in: &cancellables)

        let arguments = ProcessInfo.processInfo.arguments
        let forceOpen = arguments.contains("--show-panel") || arguments.contains("--showPopover")
        let shouldOpen = forceOpen || !model.hasLaunchedBefore
        model.markLaunched()

        guard shouldOpen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.statusBarController?.showPopover()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: AppMetadata.displayName)
        let showItem = NSMenuItem(
            title: model.t(.showPanel),
            action: #selector(showPanelFromMenu),
            keyEquivalent: "1"
        )
        showItem.target = self
        appMenu.addItem(showItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: model.t(.aboutApp, AppMetadata.displayName),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: model.t(.quitApp, AppMetadata.displayName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: model.t(.editMenu))
        editMenu.addItem(withTitle: model.t(.undo), action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: model.t(.redo), action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: model.t(.cut), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: model.t(.copy), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: model.t(.paste), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: model.t(.selectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showPanelFromMenu() {
        statusBarController?.showPopover()
    }
}
