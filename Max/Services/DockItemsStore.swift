import AppKit
import Observation

/// The items on Max's Dock: what the user keeps (persisted, imported once from Apple's Dock) and what is running.
@Observable
final class DockItemsStore {
    static let storageKey = "dockItems"

    private(set) var items: DockItems {
        didSet {
            guard items != oldValue else { return }
            persist()
        }
    }
    private(set) var running: [RunningApp] = []

    var tiles: [DockTile] {
        DockTile.tiles(items: items, running: running, trashURL: trashURL, displayName: displayName)
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var names: [URL: String] = [:]
    let trashURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(DockItems.self, from: data) {
            items = stored
        } else {
            items = Self.importedFromDock()
            persist()
        }
        refreshRunning()

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshRunning() }
            })
        }
    }

    // MARK: Kept items

    /// Replaces the kept items with Apple's Dock's current ones.
    func importFromDock() {
        items = Self.importedFromDock()
    }

    func keep(_ tile: DockTile) {
        guard tile.kind == .app, let url = tile.url else { return }
        items.keep(.app(url: url, bundleID: tile.bundleID))
    }

    func keepApps(at urls: [URL], index: Int) {
        for (offset, url) in urls.filter({ $0.pathExtension == "app" }).enumerated() {
            items.keep(.app(url: url, bundleID: Bundle(url: url)?.bundleIdentifier), at: index + offset)
        }
    }

    func remove(_ tile: DockTile) {
        guard let source = tile.source else { return }
        items.remove(in: source.section, at: source.index)
    }

    func move(in section: DockItems.Section, from source: Int, to destination: Int) {
        items.move(in: section, from: source, to: destination)
    }

    // MARK: Actions

    /// What a click does: launch or bring forward an app (reopening its window like the Dock), or open a folder.
    func open(_ tile: DockTile) {
        switch tile.kind {
        case .app:
            let runningURL = tile.processID.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL }
            guard let url = runningURL ?? tile.url else {
                if let pid = tile.processID { NSRunningApplication(processIdentifier: pid)?.activate() }
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
        case .folder, .trash:
            if let url = tile.url { NSWorkspace.shared.open(url) }
        case .spacer, .smallSpacer, .separator:
            break
        }
    }

    func open(_ files: [URL], with tile: DockTile) {
        guard tile.kind == .app, let url = tile.url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(files, withApplicationAt: url, configuration: configuration, completionHandler: nil)
    }

    func moveToTrash(_ files: [URL]) {
        NSWorkspace.shared.recycle(files, completionHandler: nil)
    }

    func showInFinder(_ tile: DockTile) {
        guard let url = tile.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func runningApplication(for tile: DockTile) -> NSRunningApplication? {
        tile.processID.flatMap { NSRunningApplication(processIdentifier: $0) }
    }

    // MARK: Private

    private func refreshRunning() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
        // Keep the existing order so tiles do not jump around; newly launched apps go last.
        let byID = Dictionary(apps.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        let known = running.map(\.processID).filter { byID[$0] != nil }
        let order = known + apps.map(\.processIdentifier).filter { !known.contains($0) }
        let updated = order.compactMap { pid -> RunningApp? in
            guard let app = byID[pid] else { return nil }
            return RunningApp(
                processID: pid, bundleID: app.bundleIdentifier, url: app.bundleURL,
                name: app.localizedName ?? app.bundleURL.map(displayName) ?? "", isActive: app.isActive
            )
        }
        if updated != running { running = updated }
    }

    private func displayName(_ url: URL) -> String {
        if let name = names[url] { return name }
        let name = FileManager.default.displayName(atPath: url.path)
        names[url] = name
        return name
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func importedFromDock() -> DockItems {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        let apps = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] ?? []
        let others = CFPreferencesCopyAppValue("persistent-others" as CFString, domain) as? [[String: Any]] ?? []
        return DockItems(dockApps: apps, dockOthers: others)
    }
}
