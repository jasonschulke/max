import AppKit
import Observation

/// Tracks the Dock's preferences and the geometry of the display it is on, refreshing when either changes.
@Observable
final class DockObserver {
    private(set) var dock = DockInfo()
    private(set) var screenFrame: CGRect = .zero
    private(set) var visibleFrame: CGRect = .zero

    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var dockDisplayID: CGDirectDisplayID?

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

        guard let screen = dockScreen(orientation: info.orientation) else { return }
        if screen.frame != screenFrame { screenFrame = screen.frame }
        if screen.visibleFrame != visibleFrame { visibleFrame = screen.visibleFrame }
    }

    /// The display reserving the Dock's strip. While the Dock auto-hides no display reserves one, so stay on
    /// the last display that did, falling back to the primary display (the first screen, origin 0,0).
    private func dockScreen(orientation: DockOrientation) -> NSScreen? {
        let screens = NSScreen.screens
        let geometry = screens.map { (frame: $0.frame, visibleFrame: $0.visibleFrame) }
        if let index = DockGeometry.dockScreenIndex(in: geometry, orientation: orientation) {
            dockDisplayID = screens[index].displayID
            return screens[index]
        }
        return screens.first { $0.displayID == dockDisplayID } ?? screens.first
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

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
