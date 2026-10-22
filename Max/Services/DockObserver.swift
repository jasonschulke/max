import AppKit
import Observation

/// Tracks the Dock's preferences and the primary display's geometry, refreshing when either changes.
@Observable
final class DockObserver {
    private(set) var dock = DockInfo()
    private(set) var screenFrame: CGRect = .zero
    private(set) var visibleFrame: CGRect = .zero

    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        refresh()

        // Fires when displays change and when the Dock's reserved strip changes (size, position, auto-hide).
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })

        // Posted by the Dock whenever its preferences are written.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    func refresh() {
        let info = DockInfo(preferences: Self.dockPreferences())
        if info != dock { dock = info }

        // The Dock lives on the primary display: the one whose frame has its origin at (0, 0).
        guard let screen = NSScreen.screens.first else { return }
        if screen.frame != screenFrame { screenFrame = screen.frame }
        if screen.visibleFrame != visibleFrame { visibleFrame = screen.visibleFrame }
    }

    private static let preferenceKeys = ["orientation", "autohide", "tilesize", "autohide-delay", "autohide-time-modifier"]

    private static func dockPreferences() -> [String: Any] {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        var values: [String: Any] = [:]
        for key in preferenceKeys {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain) {
                values[key] = value
            }
        }
        return values
    }
}
