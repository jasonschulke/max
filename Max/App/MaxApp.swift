import SwiftUI

@main
struct MaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(store: appDelegate.store, profiles: appDelegate.dockProfiles)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Dock Max")
        }

        Settings {
            SettingsView(
                store: appDelegate.store, navigation: appDelegate.settingsNavigation, loginItem: appDelegate.loginItem,
                skin: appDelegate.skinTracker, dockSize: appDelegate.dockSize, pinner: appDelegate.pinner,
                trash: appDelegate.trash, profiles: appDelegate.dockProfiles, windowCorners: appDelegate.windowCorners,
                menuBar: appDelegate.menuBar
            )
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarMenu: View {
    @Bindable var store: SettingsStore
    let profiles: DockProfiles
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Show Dock Bar", isOn: $store.configuration.isEnabled)
        if !profiles.names.isEmpty {
            Menu("Dock Profile") {
                ForEach(profiles.names, id: \.self) { name in
                    Button(name) { profiles.apply(name) }
                }
            }
        }
        Divider()
        Button("Settings…") {
            openSettings()
            // SwiftUI's Settings window; it is also Max's only titled window that isn't a panel.
            WindowFront.bring { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" || ($0.styleMask.contains(.titled) && !($0 is NSPanel)) }
        }
        .keyboardShortcut(",")
        Button("About Dock Max") {
            NSApp.orderFrontStandardAboutPanel(nil)
            WindowFront.bring { $0 is NSPanel && $0.styleMask.contains(.titled) }
        }
        Divider()
        Button("Quit Dock Max") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Brings one of Max's windows to the front. Max is a menu bar app, so it is rarely the active app when a window
/// opens, and macOS would otherwise leave the window behind the frontmost app's.
enum WindowFront {
    static func bring(_ matches: @escaping (NSWindow) -> Bool) {
        NSApp.activate()
        // SwiftUI may create the window a moment later; look again until it shows up.
        for delay in [0.0, 0.1, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let window = NSApp.windows.first(where: { $0.isVisible && matches($0) })
                    ?? NSApp.windows.first(where: matches) else { return }
                window.orderFrontRegardless()
                window.makeKey()
            }
        }
    }
}

/// Max's mark for the menu bar, after the app icon: a screen with a bar running its full width along the bottom,
/// app tiles cut out of it.
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
            // Three tiles, cut out of the bar.
            NSGraphicsContext.current?.compositingOperation = .clear
            let tile: CGFloat = 1.75
            let gap: CGFloat = 1.25
            let total = 3 * tile + 2 * gap
            for index in 0..<3 {
                NSRect(x: screen.midX - total / 2 + CGFloat(index) * (tile + gap), y: screen.minY + 1.4, width: tile, height: tile).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
