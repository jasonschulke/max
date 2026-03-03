import Cocoa

class PersistenceManager {
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Configuration Loading

    func loadConfiguration() -> OverlayConfiguration {
        var config = OverlayConfiguration()

        // Load height
        if let heightValue = userDefaults.object(forKey: StorageKey.height.rawValue) as? Double, heightValue > 0 {
            config.height = CGFloat(heightValue)
        }

        // Load opacity
        if let opacityValue = userDefaults.object(forKey: StorageKey.opacity.rawValue) as? Double, opacityValue > 0 {
            config.opacity = opacityValue
        }

        // Load background opacity
        if let bgOpacity = userDefaults.object(forKey: StorageKey.backgroundOpacity.rawValue) as? Double {
            config.backgroundOpacity = bgOpacity
        } else if userDefaults.object(forKey: StorageKey.backgroundOpacity.rawValue) == nil {
            config.backgroundOpacity = OverlayConfiguration.defaultBackgroundOpacity
        }

        // Load material index
        if userDefaults.object(forKey: StorageKey.material.rawValue) != nil {
            config.materialIndex = userDefaults.integer(forKey: StorageKey.material.rawValue)
        }

        // Load blending mode index
        if userDefaults.object(forKey: StorageKey.blendingMode.rawValue) != nil {
            config.blendingModeIndex = userDefaults.integer(forKey: StorageKey.blendingMode.rawValue)
        }

        // Load enabled state
        if let enabled = userDefaults.object(forKey: StorageKey.enabled.rawValue) as? Bool {
            config.isEnabled = enabled
        }

        // Load launch at login
        config.launchAtLogin = userDefaults.bool(forKey: StorageKey.launchAtLogin.rawValue)

        // Load custom color settings
        config.useCustomColor = userDefaults.bool(forKey: StorageKey.useCustomColor.rawValue)
        config.useGradient = userDefaults.bool(forKey: StorageKey.useGradient.rawValue)

        // Load custom color
        if let color = loadColor() {
            config.customColor = color
        }

        // Load animations enabled
        if let animationsEnabled = userDefaults.object(forKey: StorageKey.animationsEnabled.rawValue) as? Bool {
            config.animationsEnabled = animationsEnabled
        }

        return config.validated()
    }

    // MARK: - Configuration Saving

    func saveHeight(_ height: CGFloat) {
        userDefaults.set(Double(height), forKey: StorageKey.height.rawValue)
    }

    func saveOpacity(_ opacity: Double) {
        userDefaults.set(opacity, forKey: StorageKey.opacity.rawValue)
    }

    func saveBackgroundOpacity(_ opacity: Double) {
        userDefaults.set(opacity, forKey: StorageKey.backgroundOpacity.rawValue)
    }

    func saveMaterialIndex(_ index: Int) {
        userDefaults.set(index, forKey: StorageKey.material.rawValue)
    }

    func saveBlendingModeIndex(_ index: Int) {
        userDefaults.set(index, forKey: StorageKey.blendingMode.rawValue)
    }

    func saveEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: StorageKey.enabled.rawValue)
    }

    func saveLaunchAtLogin(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: StorageKey.launchAtLogin.rawValue)
    }

    func saveUseCustomColor(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: StorageKey.useCustomColor.rawValue)
    }

    func saveUseGradient(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: StorageKey.useGradient.rawValue)
    }

    func saveAnimationsEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: StorageKey.animationsEnabled.rawValue)
    }

    // MARK: - Color Persistence (Secure Coding)

    func saveColor(_ color: NSColor) {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: color,
                requiringSecureCoding: true
            )
            userDefaults.set(data, forKey: StorageKey.customColor.rawValue)
        } catch {
            print("Failed to archive color with secure coding: \(error)")
            // Fallback: try without secure coding for compatibility
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
                userDefaults.set(data, forKey: StorageKey.customColor.rawValue)
            }
        }
    }

    func loadColor() -> NSColor? {
        guard let data = userDefaults.data(forKey: StorageKey.customColor.rawValue) else {
            return nil
        }

        // Use modern secure coding API (macOS 10.14+)
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        let keys: [StorageKey] = [
            .height, .opacity, .material, .enabled, .blendingMode,
            .backgroundOpacity, .useCustomColor, .customColor,
            .useGradient, .animationsEnabled
        ]

        keys.forEach { userDefaults.removeObject(forKey: $0.rawValue) }
    }
}
