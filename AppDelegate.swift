import Cocoa
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var configService: ConfigurationService!
    private var overlayWindowController: OverlayWindowController!
    private var settingsWindowController: SettingsWindowController!
    private var menuBarManager: MenuBarManager!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("=== AppDelegate: applicationDidFinishLaunching called ===")

        // Initialize configuration service
        NSLog("AppDelegate: Creating ConfigurationService")
        configService = ConfigurationService()

        // Setup menu bar
        NSLog("AppDelegate: Creating MenuBarManager")
        menuBarManager = MenuBarManager(delegate: self)

        // Setup overlay window
        NSLog("AppDelegate: Creating OverlayWindowController")
        overlayWindowController = OverlayWindowController(configService: configService)

        // Setup settings window
        NSLog("AppDelegate: Creating SettingsWindowController")
        settingsWindowController = SettingsWindowController(configService: configService)

        // Show settings window on first launch
        NSLog("AppDelegate: Showing settings window")
        settingsWindowController.show()

        // Subscribe to configuration changes
        NSLog("AppDelegate: Setting up configuration observers")
        setupConfigurationObservers()

        NSLog("=== AppDelegate: Initialization complete ===")
    }

    // MARK: - Configuration Observers

    private func setupConfigurationObservers() {
        // Observe enabled state changes to show/hide overlay
        configService.$configuration
            .map { $0.isEnabled }
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.updateOverlayVisibility(isEnabled)
            }
            .store(in: &cancellables)
    }

    private func updateOverlayVisibility(_ isEnabled: Bool) {
        let animated = configService.configuration.animationsEnabled
        if isEnabled {
            overlayWindowController.show(animated: animated)
        } else {
            overlayWindowController.hide(animated: animated)
        }
    }
}

// MARK: - Menu Bar Delegate

extension AppDelegate: MenuBarDelegate {
    func menuBarToggleOverlay() {
        configService.updateEnabled(!configService.configuration.isEnabled)
    }

    func menuBarShowSettings() {
        settingsWindowController.show()
    }

    func menuBarShowAbout() {
        let alert = NSAlert()
        alert.messageText = "Max"
        alert.informativeText = "Version 1.0\n\nA utility to customize your macOS dock appearance with custom colors, gradients, and visual effects.\n\n© 2026"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Settings Window Delegate

extension AppDelegate: SettingsWindowDelegate {
    func settingsLaunchAtLoginToggled(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            configService.updateLaunchAtLogin(enabled)
        } catch {
            LaunchAtLoginManager.showErrorAlert(for: error, enabled: enabled)
        }
    }
}
