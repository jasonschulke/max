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

    /// An app with its own radius, set in its own preferences, which take precedence over the global one.
    struct Exception: Identifiable, Equatable, Sendable {
        /// The app's bundle identifier.
        var id: String
        var name: String
        var url: URL?
        var radius: Double
        /// Sandboxed apps read their settings from their own container, which Max does not write to.
        var isSandboxed: Bool
    }

    /// Nil while apps use the system's own radius.
    private(set) var radius: Double?
    private(set) var exceptions: [Exception] = []
    /// Apps waiting for the user to confirm a relaunch.
    private(set) var pendingRelaunch: [App] = []

    var isOverridden: Bool { radius != nil }

    /// How long an app gets to quit before Max gives up reopening it (say it is asking to save a document).
    private let quitTimeout = 15.0
    private static let finderID = "com.apple.finder"
    /// Max's record of the exceptions it set: bundle identifier to radius.
    static let exceptionsKey = "windowCornerExceptions"

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        let stored = defaults.dictionary(forKey: Self.exceptionsKey) as? [String: Double] ?? [:]
        exceptions = stored.map { Self.exception(for: $0.key, radius: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

    // MARK: Exceptions

    /// Adds apps as exceptions. They start out as the opposite of the global setting: rounded while windows are
    /// square, and square otherwise.
    func addExceptions(_ urls: [URL]) {
        for url in urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier, !exceptions.contains(where: { $0.id == bundleID }) else { continue }
            let radius = isOverridden ? WindowCornerRadius.systemDefault : 0
            exceptions.append(Self.exception(for: bundleID, radius: radius))
            writeException(bundleID, radius: radius)
        }
        exceptions.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persistExceptions()
    }

    func setException(_ bundleID: String, radius: Double) {
        guard let index = exceptions.firstIndex(where: { $0.id == bundleID }) else { return }
        exceptions[index].radius = radius
        writeException(bundleID, radius: radius)
        persistExceptions()
    }

    func removeException(_ bundleID: String) {
        exceptions.removeAll { $0.id == bundleID }
        writeException(bundleID, radius: nil)
        persistExceptions()
    }

    private func writeException(_ bundleID: String, radius: Double?) {
        let value = radius.map { NSNumber(value: WindowCornerRadius.storedValue(forRadius: $0)) }
        CFPreferencesSetAppValue(WindowCornerRadius.defaultsKey as CFString, value, bundleID as CFString)
        CFPreferencesAppSynchronize(bundleID as CFString)
    }

    private func persistExceptions() {
        defaults.set(Dictionary(uniqueKeysWithValues: exceptions.map { ($0.id, $0.radius) }), forKey: Self.exceptionsKey)
    }

    private static func exception(for bundleID: String, radius: Double) -> Exception {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let container = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/\(bundleID)").path
        return Exception(
            id: bundleID, name: url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID, url: url,
            radius: radius, isSandboxed: FileManager.default.fileExists(atPath: container)
        )
    }

    // MARK: Relaunching

    /// Finder reopens on its own when it quits, and holds no documents, so it is safe to restart right away.
    func relaunchFinder() {
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Finder"]
        try? killall.run()
    }

    /// Lists the apps a relaunch would quit and reopen (all of them, or one), for the user to confirm.
    func prepareRelaunch(only bundleID: String? = nil) {
        let ownID = Bundle.main.bundleIdentifier
        pendingRelaunch = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, app.bundleIdentifier != ownID, let url = app.bundleURL,
                  bundleID == nil || app.bundleIdentifier == bundleID else { return nil }
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
