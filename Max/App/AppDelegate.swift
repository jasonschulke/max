import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore()
    let dockObserver = DockObserver()
    let loginItem = LoginItemSettings()
    let dockItems = DockItemsStore()

    private var overlay: OverlayController?
    private var hotKey: GlobalHotKey?
    private var hotKeyTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayController(store: store, dockObserver: dockObserver, dockItems: dockItems)
        overlay.start()
        self.overlay = overlay

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
