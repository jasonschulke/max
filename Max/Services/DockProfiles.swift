import AppKit
import Observation

/// Saved arrangements of Apple's Dock (`persistent-apps` and `persistent-others` in `com.apple.dock`), plus adding
/// spacers and restoring the Dock from before Max first changed it. Each change restarts the Dock to load it.
/// Rearranging itself happens in the Dock, by dragging.
@Observable
final class DockProfiles {
    enum Section: Sendable {
        case apps, others

        var preferenceKey: String { self == .apps ? "persistent-apps" : "persistent-others" }
    }

    /// Saved profiles, sorted by name.
    private(set) var names: [String] = []
    private(set) var hasBackup = false

    // Drive the prompts in Settings.
    var isNaming = false
    var renaming: String?
    var deleting: String?
    var isConfirmingRestore = false
    var draftName = ""

    @ObservationIgnored private let defaults: UserDefaults
    private static let domain = "com.apple.dock" as CFString
    /// Max's copy of the Dock's items from before its first change.
    static let backupKey = "dockBackup"
    /// Saved arrangements: name to the Dock's two item lists.
    static let profilesKey = "dockProfiles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        names = Self.sortedNames(profiles)
        hasBackup = defaults.dictionary(forKey: Self.backupKey) != nil
    }

    /// Saves the Dock as it is now under a name, replacing a profile with the same name.
    func saveCurrentDock(as name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var saved = profiles
        saved[name] = [
            Section.apps.preferenceKey: Self.read(.apps),
            Section.others.preferenceKey: Self.read(.others),
        ]
        store(saved)
        draftName = ""
    }

    /// Puts a saved arrangement on the Dock.
    func apply(_ name: String) {
        guard let profile = profiles[name] as? [String: Any] else { return }
        write(apps: profile[Section.apps.preferenceKey] as? [[String: Any]] ?? [],
              others: profile[Section.others.preferenceKey] as? [[String: Any]] ?? [])
    }

    func rename(_ name: String, to newName: String) {
        let newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != name else { return }
        var saved = profiles
        saved[newName] = saved[name]
        saved[name] = nil
        store(saved)
        draftName = ""
    }

    func delete(_ name: String) {
        var saved = profiles
        saved[name] = nil
        store(saved)
    }

    /// Adds a spacer at the end of the Dock's apps, to drag into place in the Dock.
    func addSpacer(small: Bool) {
        let spacer = (small ? DockTile.smallSpacer : DockTile.spacer).preferences
        write(apps: Self.read(.apps) + [spacer], others: Self.read(.others))
    }

    /// Puts back the Dock's items from before Max's first change.
    func restoreBackup() {
        guard let backup = defaults.dictionary(forKey: Self.backupKey) else { return }
        for section in [Section.apps, .others] {
            Self.write(backup[section.preferenceKey] as? [[String: Any]] ?? [], to: section)
        }
        Self.restartDock()
    }

    // MARK: Private

    private var profiles: [String: Any] {
        defaults.dictionary(forKey: Self.profilesKey) ?? [:]
    }

    private func store(_ profiles: [String: Any]) {
        defaults.set(profiles, forKey: Self.profilesKey)
        names = Self.sortedNames(profiles)
    }

    private static func sortedNames(_ profiles: [String: Any]) -> [String] {
        profiles.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Writes both lists to the Dock and restarts it, keeping a backup of the Dock from before Max's first write.
    private func write(apps: [[String: Any]], others: [[String: Any]]) {
        if !hasBackup {
            defaults.set([
                Section.apps.preferenceKey: Self.read(.apps),
                Section.others.preferenceKey: Self.read(.others),
            ], forKey: Self.backupKey)
            hasBackup = true
        }
        Self.write(apps, to: .apps)
        Self.write(others, to: .others)
        Self.restartDock()
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
