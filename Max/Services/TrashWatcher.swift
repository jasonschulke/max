import AppKit
import Observation

/// Whether the Trash has anything in it, so the skin can show the full Trash icon. macOS protects the Trash
/// folder, so this needs Full Disk Access; without it the Trash always looks empty.
@Observable
final class TrashWatcher {
    private(set) var isFull = false
    private(set) var hasAccess = false

    @ObservationIgnored private var source: (any DispatchSourceFileSystemObject)?
    @ObservationIgnored private var accessTimer: Timer?
    @ObservationIgnored private let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)

    /// How often to look again for Full Disk Access once it is missing.
    private let accessCheckInterval = 5.0

    init() {
        check()
        if hasAccess {
            watch()
        } else {
            accessTimer = Timer.scheduledTimer(withTimeInterval: accessCheckInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkForAccess() }
            }
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkForAccess() {
        check()
        guard hasAccess else { return }
        accessTimer?.invalidate()
        accessTimer = nil
        watch()
    }

    private func check() {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: trash.path) else {
            if hasAccess { hasAccess = false }
            return
        }
        if !hasAccess { hasAccess = true }
        let full = contents.contains { $0 != ".DS_Store" }
        if full != isFull { isFull = full }
    }

    /// Re-checks whenever the Trash folder changes.
    private func watch() {
        let descriptor = open(trash.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.check() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
