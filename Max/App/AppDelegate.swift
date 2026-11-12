import AppKit
import Observation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore()
    let dockObserver = DockObserver()
    let loginItem = LoginItemSettings()
    let skinTracker = DockSkinTracker()
    let dockEditor = DockEditor()

    private var overlay: OverlayController?
    private var hotKey: GlobalHotKey?
    private var hotKeyTask: Task<Void, Never>?
    private var dockEditorWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayController(store: store, dockObserver: dockObserver, skinTracker: skinTracker)
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

    /// Opens the Dock item editor, re-reading the Dock unless an edit is still pending.
    func showDockEditor() {
        if !dockEditor.hasChanges { dockEditor.reload() }
        if dockEditorWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: DockEditorView(editor: dockEditor)))
            window.title = "Dock Items"
            window.setContentSize(NSSize(width: 420, height: 640))
            window.isReleasedWhenClosed = false
            window.center()
            dockEditorWindow = window
        }
        NSApp.activate()
        dockEditorWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
