import Cocoa

// MARK: - Storage Keys

enum StorageKey: String {
    case height = "overlayHeight"
    case opacity = "overlayOpacity"
    case material = "overlayMaterial"
    case enabled = "overlayEnabled"
    case blendingMode = "overlayBlendingMode"
    case backgroundOpacity = "backgroundOpacity"
    case launchAtLogin = "launchAtLogin"
    case useCustomColor = "useCustomColor"
    case customColor = "customColor"
    case useGradient = "useGradient"
    case animationsEnabled = "animationsEnabled"
}

// MARK: - Material Definitions

struct MaterialOption {
    let name: String
    let material: NSVisualEffectView.Material
}

struct BlendingModeOption {
    let name: String
    let mode: NSVisualEffectView.BlendingMode
}

// MARK: - Configuration Model

struct OverlayConfiguration {
    var height: CGFloat
    var opacity: Double
    var materialIndex: Int
    var isEnabled: Bool
    var blendingModeIndex: Int
    var backgroundOpacity: Double
    var launchAtLogin: Bool
    var useCustomColor: Bool
    var customColor: NSColor
    var useGradient: Bool
    var animationsEnabled: Bool

    // MARK: - Default Values

    static let defaultHeight: CGFloat = 50
    static let defaultOpacity: Double = 0.9
    static let defaultMaterialIndex: Int = 0
    static let defaultIsEnabled: Bool = true
    static let defaultBlendingModeIndex: Int = 0
    static let defaultBackgroundOpacity: Double = 0.85
    static let defaultLaunchAtLogin: Bool = false
    static let defaultUseCustomColor: Bool = false
    static let defaultCustomColor: NSColor = .windowBackgroundColor
    static let defaultUseGradient: Bool = false
    static let defaultAnimationsEnabled: Bool = true

    // MARK: - Material Options

    static let materials: [MaterialOption] = [
        MaterialOption(name: "Under Window Background (Best)", material: .underWindowBackground),
        MaterialOption(name: "Window Background", material: .windowBackground),
        MaterialOption(name: "Titlebar", material: .titlebar),
        MaterialOption(name: "Menu", material: .menu),
        MaterialOption(name: "Popover", material: .popover),
        MaterialOption(name: "Header View", material: .headerView),
        MaterialOption(name: "Sheet", material: .sheet),
        MaterialOption(name: "HUD Window", material: .hudWindow),
        MaterialOption(name: "Sidebar", material: .sidebar),
        MaterialOption(name: "Content Background", material: .contentBackground)
    ]

    // MARK: - Blending Mode Options

    static let blendingModes: [BlendingModeOption] = [
        BlendingModeOption(name: "Behind Window", mode: .behindWindow),
        BlendingModeOption(name: "Within Window", mode: .withinWindow)
    ]

    // MARK: - Initializers

    init(
        height: CGFloat = defaultHeight,
        opacity: Double = defaultOpacity,
        materialIndex: Int = defaultMaterialIndex,
        isEnabled: Bool = defaultIsEnabled,
        blendingModeIndex: Int = defaultBlendingModeIndex,
        backgroundOpacity: Double = defaultBackgroundOpacity,
        launchAtLogin: Bool = defaultLaunchAtLogin,
        useCustomColor: Bool = defaultUseCustomColor,
        customColor: NSColor = defaultCustomColor,
        useGradient: Bool = defaultUseGradient,
        animationsEnabled: Bool = defaultAnimationsEnabled
    ) {
        self.height = height
        self.opacity = opacity
        self.materialIndex = materialIndex
        self.isEnabled = isEnabled
        self.blendingModeIndex = blendingModeIndex
        self.backgroundOpacity = backgroundOpacity
        self.launchAtLogin = launchAtLogin
        self.useCustomColor = useCustomColor
        self.customColor = customColor
        self.useGradient = useGradient
        self.animationsEnabled = animationsEnabled
    }

    // MARK: - Computed Properties

    var material: NSVisualEffectView.Material {
        guard materialIndex >= 0 && materialIndex < Self.materials.count else {
            return Self.materials[Self.defaultMaterialIndex].material
        }
        return Self.materials[materialIndex].material
    }

    var blendingMode: NSVisualEffectView.BlendingMode {
        guard blendingModeIndex >= 0 && blendingModeIndex < Self.blendingModes.count else {
            return Self.blendingModes[Self.defaultBlendingModeIndex].mode
        }
        return Self.blendingModes[blendingModeIndex].mode
    }

    // MARK: - Validation

    func validated() -> OverlayConfiguration {
        var config = self

        // Validate height
        config.height = max(20, min(300, config.height))

        // Validate opacity
        config.opacity = max(0.1, min(1.0, config.opacity))

        // Validate background opacity
        config.backgroundOpacity = max(0.0, min(1.0, config.backgroundOpacity))

        // Validate material index
        if config.materialIndex < 0 || config.materialIndex >= Self.materials.count {
            config.materialIndex = Self.defaultMaterialIndex
        }

        // Validate blending mode index
        if config.blendingModeIndex < 0 || config.blendingModeIndex >= Self.blendingModes.count {
            config.blendingModeIndex = Self.defaultBlendingModeIndex
        }

        return config
    }
}
