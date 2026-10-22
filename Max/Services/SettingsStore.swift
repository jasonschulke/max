import AppKit
import Observation

/// Single source of truth for the user's configuration. Persists as one JSON blob in UserDefaults
/// and migrates the per-key layout Max 1.0 used.
@Observable
final class SettingsStore {
    static let storageKey = "configuration"

    var configuration: OverlayConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            persist()
        }
    }

    /// True while a slider is being dragged. The overlay then applies changes without animation so it tracks the pointer.
    var isInteracting = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(OverlayConfiguration.self, from: data) {
            configuration = stored
        } else if let migrated = OverlayConfiguration(
            legacyDefaults: defaults.dictionaryRepresentation(),
            legacyColor: Self.legacyColor(in: defaults)
        ) {
            configuration = migrated
            persist()
        } else {
            configuration = OverlayConfiguration()
        }
    }

    func resetToDefaults() {
        configuration = OverlayConfiguration()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Max 1.0 archived its NSColor with NSKeyedArchiver.
    private static func legacyColor(in defaults: UserDefaults) -> RGBAColor? {
        guard let data = defaults.data(forKey: "customColor"),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return RGBAColor(color)
    }
}
