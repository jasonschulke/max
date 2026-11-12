import SwiftUI

@main
struct MaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Max", systemImage: "dock.rectangle") {
            MenuBarMenu(store: appDelegate.store)
        }

        Settings {
            SettingsView(
                store: appDelegate.store, loginItem: appDelegate.loginItem,
                skin: appDelegate.skinTracker, windowCorners: appDelegate.windowCorners,
                showDockEditor: appDelegate.showDockEditor
            )
        }
    }
}

private struct MenuBarMenu: View {
    @Bindable var store: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Show Dock Bar", isOn: $store.configuration.isEnabled)
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("About Max") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Divider()
        Button("Quit Max") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
