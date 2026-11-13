import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    // First, so it can copy pre-rename settings before the other stores read theirs.
    let store = SettingsStore()
    let dockObserver = DockObserver()
    let loginItem = LoginItemSettings()
    let skinTracker = DockSkinTracker()
    let dockProfiles = DockProfiles()
    let settingsNavigation = SettingsNavigation()
    let windowCorners = WindowCornerOverride()
    let dockSize = DockSize()
    let pinner = DockPinner()
    let trash = TrashWatcher()
    let idle = IdleWatcher()

    private var overlay: OverlayController?
    private var hotKey: GlobalHotKey?
    private var hotKeyTask: Task<Void, Never>?
    private var pinTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayController(store: store, dockObserver: dockObserver, skinTracker: skinTracker, trash: trash, idle: idle)
        overlay.start()
        self.overlay = overlay

        pinTask = Task { [store, dockObserver, pinner] in
            for await (display, orientation) in Observations({ (store.configuration.pinnedDisplay, dockObserver.dock.orientation) }) {
                pinner.update(pinnedDisplay: display, orientation: orientation)
            }
        }

        let hotKey = GlobalHotKey(shortcut: .toggleOverlay) { [store] in
            store.configuration.isEnabled.toggle()
        }
        self.hotKey = hotKey
        hotKeyTask = Task { [store] in
            for await enabled in Observations({ store.configuration.globalShortcutEnabled }) {
                if enabled { hotKey.register() } else { hotKey.unregister() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
