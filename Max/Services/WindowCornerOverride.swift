import AppKit
import Observation

/// The corner radius every app's windows use: a global default apps read when they launch, so changing it
/// also means relaunching apps.
@Observable
final class WindowCornerOverride {
    /// An app to quit and reopen.
    struct App: Identifiable, Sendable {
        var id: pid_t
        var name: String
        var url: URL
    }

    /// Nil while apps use the system's own radius.
    private(set) var radius: Double?
    /// Apps waiting for the user to confirm a relaunch.
    private(set) var pendingRelaunch: [App] = []

    var isOverridden: Bool { radius != nil }

    /// How long an app gets to quit before Max gives up reopening it (say it is asking to save a document).
    private let quitTimeout = 15.0
    private static let finderID = "com.apple.finder"

    init() {
        reload()
    }

    func reload() {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let stored = CFPreferencesCopyAppValue(WindowCornerRadius.defaultsKey as CFString, kCFPreferencesAnyApplication) as? NSNumber
        radius = WindowCornerRadius.radius(fromStored: stored?.doubleValue)
    }

    func setOverridden(_ overridden: Bool) {
        if overridden {
            set(radius: radius ?? 0)
        } else {
            write(nil)
            radius = nil
        }
    }

    func set(radius newRadius: Double) {
        let stored = WindowCornerRadius.storedValue(forRadius: newRadius)
        write(stored)
        radius = WindowCornerRadius.radius(fromStored: stored)
    }

    // MARK: Relaunching

    /// Finder reopens on its own when it quits, and holds no documents, so it is safe to restart right away.
    func relaunchFinder() {
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Finder"]
        try? killall.run()
    }

    /// Lists the apps a relaunch would quit and reopen, for the user to confirm.
    func prepareRelaunch() {
        let ownID = Bundle.main.bundleIdentifier
        pendingRelaunch = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, app.bundleIdentifier != ownID, let url = app.bundleURL else { return nil }
            return App(id: app.processIdentifier, name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, url: url)
        }
    }

    func cancelRelaunch() {
        pendingRelaunch = []
    }

    /// Asks each app to quit (so it can offer to save) and reopens it once it has, in the background.
    func confirmRelaunch() {
        let apps = pendingRelaunch
        pendingRelaunch = []
        for app in apps {
            if NSRunningApplication(processIdentifier: app.id)?.bundleIdentifier == Self.finderID {
                relaunchFinder()
                continue
            }
            guard NSRunningApplication(processIdentifier: app.id)?.terminate() == true else { continue }
            reopen(app, after: Date().addingTimeInterval(quitTimeout))
        }
    }

    private func reopen(_ app: App, after deadline: Date) {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            let done = MainActor.assumeIsolated { Self.reopenIfQuit(app, deadline: deadline) }
            if done { timer.invalidate() }
        }
    }

    /// Reopens the app once it has quit. True when there is nothing left to wait for.
    private static func reopenIfQuit(_ app: App, deadline: Date) -> Bool {
        guard NSRunningApplication(processIdentifier: app.id) == nil else {
            // Still running past the deadline: the user kept it open, perhaps to save a document.
            return Date() > deadline
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration, completionHandler: nil)
        return true
    }

    // MARK: Private

    private func write(_ value: Double?) {
        CFPreferencesSetAppValue(WindowCornerRadius.defaultsKey as CFString, value.map { NSNumber(value: $0) }, kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    }
}
