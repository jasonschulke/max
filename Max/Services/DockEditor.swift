import AppKit
import Observation

/// Edits what Apple's Dock keeps (`persistent-apps` and `persistent-others` in `com.apple.dock`), then applies the
/// edit by restarting the Dock. The Dock's own entries are written back untouched; only their order changes.
@Observable
final class DockEditor {
    enum Section: Sendable {
        case apps, others

        var preferenceKey: String { self == .apps ? "persistent-apps" : "persistent-others" }
    }

    struct Entry: Identifiable {
        let id = UUID()
        let tile: DockTile
        /// The Dock's dictionary for the entry, kept so the Dock gets back exactly what it wrote.
        let preferences: [String: Any]

        init(preferences: [String: Any]) {
            self.tile = DockTile(preferences: preferences)
            self.preferences = preferences
        }

        init(tile: DockTile) {
            self.tile = tile
            self.preferences = tile.preferences
        }

        var title: String {
            switch tile {
            case .app(let url, _), .folder(let url): FileManager.default.displayName(atPath: url.path)
            case .spacer: "Spacer"
            case .smallSpacer: "Small Spacer"
            case .other(let type): type
            }
        }
    }

    private(set) var apps: [Entry] = []
    private(set) var others: [Entry] = []
    var selection: Set<UUID> = []
    private(set) var hasChanges = false

    @ObservationIgnored private let defaults: UserDefaults
    private static let domain = "com.apple.dock" as CFString
    /// Max's copy of the Dock's items from before its first edit.
    static let backupKey = "dockBackup"

    var hasBackup: Bool { defaults.dictionary(forKey: Self.backupKey) != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    /// Reads the Dock's current items, dropping unapplied edits.
    func reload() {
        apps = Self.read(.apps).map(Entry.init(preferences:))
        others = Self.read(.others).map(Entry.init(preferences:))
        selection = []
        hasChanges = false
    }

    func move(in section: Section, from source: IndexSet, to destination: Int) {
        update(section) { $0.move(fromOffsets: source, toOffset: destination) }
    }

    func removeSelected() {
        guard !selection.isEmpty else { return }
        update(.apps) { $0.removeAll { selection.contains($0.id) } }
        update(.others) { $0.removeAll { selection.contains($0.id) } }
        selection = []
    }

    /// Adds apps after the selected app (or at the end), skipping ones the Dock already keeps.
    func addApps(_ urls: [URL]) {
        let kept = Set(apps.compactMap { entry -> String? in
            if case .app(let url, _) = entry.tile { return url.standardizedFileURL.path }
            return nil
        })
        let new = urls.filter { !kept.contains($0.standardizedFileURL.path) }
            .map { Entry(tile: .app(url: $0, bundleID: Bundle(url: $0)?.bundleIdentifier)) }
        insert(new, in: .apps)
    }

    func addFolders(_ urls: [URL]) {
        insert(urls.map { Entry(tile: .folder(url: $0)) }, in: .others)
    }

    func addSpacer(small: Bool) {
        insert([Entry(tile: small ? .smallSpacer : .spacer)], in: .apps)
    }

    /// Writes the edit to the Dock's preferences and restarts the Dock to load it. The first time, keeps a backup.
    func apply() {
        if !hasBackup {
            defaults.set([
                Section.apps.preferenceKey: Self.read(.apps),
                Section.others.preferenceKey: Self.read(.others),
            ], forKey: Self.backupKey)
        }
        Self.write(apps.map(\.preferences), to: .apps)
        Self.write(others.map(\.preferences), to: .others)
        Self.restartDock()
        hasChanges = false
    }

    /// Puts back the Dock's items from before Max's first edit.
    func restoreBackup() {
        guard let backup = defaults.dictionary(forKey: Self.backupKey) else { return }
        for section in [Section.apps, .others] {
            Self.write(backup[section.preferenceKey] as? [[String: Any]] ?? [], to: section)
        }
        Self.restartDock()
        reload()
    }

    // MARK: Private

    private func update(_ section: Section, _ change: (inout [Entry]) -> Void) {
        if section == .apps { change(&apps) } else { change(&others) }
        hasChanges = true
    }

    private func insert(_ entries: [Entry], in section: Section) {
        guard !entries.isEmpty else { return }
        update(section) { list in
            let anchor = list.lastIndex { selection.contains($0.id) }
            list.insert(contentsOf: entries, at: anchor.map { $0 + 1 } ?? list.count)
        }
        selection = Set(entries.map(\.id))
    }

    private static func read(_ section: Section) -> [[String: Any]] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(section.preferenceKey as CFString, domain) as? [[String: Any]] ?? []
    }

    private static func write(_ tiles: [[String: Any]], to section: Section) {
        CFPreferencesSetAppValue(section.preferenceKey as CFString, tiles as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
    }

    private static func restartDock() {
        // launchd starts the Dock again right away, and it loads its preferences fresh.
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        try? killall.run()
    }
}
