import SwiftUI

@main
struct MaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(store: appDelegate.store, dockEditor: appDelegate.dockEditor)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Max")
        }

        Settings {
            SettingsView(
                store: appDelegate.store, loginItem: appDelegate.loginItem, skin: appDelegate.skinTracker,
                dockSize: appDelegate.dockSize, pinner: appDelegate.pinner, trash: appDelegate.trash, dockEditor: appDelegate.dockEditor,
                windowCorners: appDelegate.windowCorners
            )
        }
    }
}

private struct MenuBarMenu: View {
    @Bindable var store: SettingsStore
    let dockEditor: DockEditor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Show Dock Bar", isOn: $store.configuration.isEnabled)
        if !dockEditor.profileNames.isEmpty {
            Menu("Dock Profile") {
                ForEach(dockEditor.profileNames, id: \.self) { name in
                    Button(name) { dockEditor.applyProfile(named: name) }
                }
            }
        }
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

/// Max's mark for the menu bar: a screen with a bar running its full width along the bottom.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let screen = NSRect(x: 1.75, y: 2.75, width: 14.5, height: 12.5)
            let outline = NSBezierPath(roundedRect: screen, xRadius: 2.75, yRadius: 2.75)
            outline.lineWidth = 1.5
            NSColor.black.set()
            outline.stroke()
            // The bar fills the bottom of the screen edge to edge, flat on top.
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: screen, xRadius: 2.75, yRadius: 2.75).addClip()
            NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: 4.5).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
