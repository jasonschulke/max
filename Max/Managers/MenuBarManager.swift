import Cocoa

// MARK: - Delegate Protocol

protocol MenuBarDelegate: AnyObject {
    func menuBarToggleOverlay()
    func menuBarShowSettings()
    func menuBarShowAbout()
}

// MARK: - Menu Bar Manager

class MenuBarManager {
    private var statusItem: NSStatusItem?
    private weak var delegate: MenuBarDelegate?

    // MARK: - Initialization

    init(delegate: MenuBarDelegate) {
        self.delegate = delegate
        setupMenuBar()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.title = "M"
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Toggle Overlay",
                action: #selector(toggleOverlay),
                keyEquivalent: "t"
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Settings...",
                action: #selector(showSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "About",
                action: #selector(showAbout),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        // Set targets for menu items
        if let toggleItem = menu.item(withTitle: "Toggle Overlay") {
            toggleItem.target = self
        }
        if let settingsItem = menu.item(withTitle: "Settings...") {
            settingsItem.target = self
        }
        if let aboutItem = menu.item(withTitle: "About") {
            aboutItem.target = self
        }

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func toggleOverlay() {
        delegate?.menuBarToggleOverlay()
    }

    @objc private func showSettings() {
        delegate?.menuBarShowSettings()
    }

    @objc private func showAbout() {
        delegate?.menuBarShowAbout()
    }
}
