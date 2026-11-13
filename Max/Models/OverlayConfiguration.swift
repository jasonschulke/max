import Foundation

/// Everything the user can tune. Stored as one JSON blob in UserDefaults.
nonisolated struct OverlayConfiguration: Codable, Equatable, Sendable {

    enum Style: String, Codable, CaseIterable, Identifiable, Sendable {
        case glass
        case clearGlass
        case blur
        /// No material: just the bar's color.
        case solid

        var id: String { rawValue }

        var title: String {
            switch self {
            case .glass: "Liquid Glass"
            case .clearGlass: "Clear Glass"
            case .blur: "Blur"
            case .solid: "Solid"
            }
        }
    }

    /// NSVisualEffectView materials, by name so the stored value survives reordering.
    enum BlurMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
        case underWindowBackground
        case windowBackground
        case titlebar
        case menu
        case popover
        case headerView
        case sheet
        case hudWindow
        case sidebar
        case contentBackground
        case fullScreenUI
        case toolTip

        var id: String { rawValue }

        var title: String {
            switch self {
            case .underWindowBackground: "Under Window Background"
            case .windowBackground: "Window Background"
            case .titlebar: "Titlebar"
            case .menu: "Menu"
            case .popover: "Popover"
            case .headerView: "Header View"
            case .sheet: "Sheet"
            case .hudWindow: "HUD Window"
            case .sidebar: "Sidebar"
            case .contentBackground: "Content Background"
            case .fullScreenUI: "Full Screen UI"
            case .toolTip: "Tool Tip"
            }
        }

        /// Order used by the Max 1.0 material popup, for migrating `overlayMaterial`.
        static let legacyOrder: [BlurMaterial] = [
            .underWindowBackground, .windowBackground, .titlebar, .menu, .popover,
            .headerView, .sheet, .hudWindow, .sidebar, .contentBackground,
        ]
    }

    enum HeightMode: String, Codable, CaseIterable, Identifiable, Sendable {
        case matchDock
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .matchDock: "Match Dock"
            case .custom: "Custom"
            }
        }
    }

    struct Tint: Codable, Equatable, Sendable {
        var isEnabled = false
        var color = RGBAColor(red: 0.08, green: 0.08, blue: 0.1)
        var strength = 0.35
        /// Fade the tint out toward the top edge (a vertical gradient).
        var fadesUpward = false

        init(isEnabled: Bool = false, color: RGBAColor = RGBAColor(red: 0.08, green: 0.08, blue: 0.1), strength: Double = 0.35, fadesUpward: Bool = false) {
            self.isEnabled = isEnabled
            self.color = color
            self.strength = strength
            self.fadesUpward = fadesUpward
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = Tint()
            isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
            color = try container.decodeIfPresent(RGBAColor.self, forKey: .color) ?? defaults.color
            strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? defaults.strength
            fadesUpward = try container.decodeIfPresent(Bool.self, forKey: .fadesUpward) ?? defaults.fadesUpward
        }
    }

    var isEnabled = true
    /// Sit over Apple's Dock and draw its icons where it draws them (needs Accessibility access),
    /// instead of sitting behind it.
    var skinsDock = false
    /// Dots under running apps, drawn over the Dock.
    var showsIndicators = true
    /// Notification badges on icons, drawn over the Dock.
    var showsBadges = true
    /// Icons hop while their app launches, as the Dock's do.
    var bouncesOnLaunch = true
    /// Scales the icons Max draws over the Dock, around the Dock's own size; spacing stays the Dock's.
    var iconScale = 1.0
    /// The display the Dock is kept on (its CoreGraphics UUID), or nil to let it move freely.
    var pinnedDisplay: String?
    var style: Style = .glass
    var blurMaterial: BlurMaterial = .underWindowBackground
    /// Alpha of the bar's material (and, behind Apple's Dock, of the whole bar).
    var opacity = 1.0
    var heightMode: HeightMode = .matchDock
    /// Points added to (or removed from) the Dock's reserved strip in `matchDock` mode.
    var heightAdjustment = 0.0
    /// Absolute thickness in points, used in `custom` mode.
    var customHeight = 50.0
    /// Radius of the two corners that face into the screen.
    var cornerRadius = 0.0
    var tint = Tint()
    var animationsEnabled = true
    /// Reveal and dismiss the bar along with an auto-hiding Dock. When off, the bar hides whenever the Dock auto-hides.
    var mirrorsDockAutoHide = true
    /// ⌃⌥⌘M toggles the bar from anywhere.
    var globalShortcutEnabled = true

    static let opacityRange = 0.1...1.0
    static let heightAdjustmentRange = -40.0...120.0
    static let customHeightRange = 20.0...300.0
    static let cornerRadiusRange = 0.0...40.0
    static let tintStrengthRange = 0.0...1.0
    /// Past 125%, icons would start to touch at the Dock's spacing.
    static let iconScaleRange = 0.5...1.25

    init() {}

    // MARK: Codable (missing or unknown values fall back to defaults)

    private enum CodingKeys: String, CodingKey {
        case isEnabled, skinsDock, showsIndicators, showsBadges, bouncesOnLaunch, iconScale, pinnedDisplay, style, blurMaterial, opacity, heightMode, heightAdjustment, customHeight
        case cornerRadius, tint, animationsEnabled, mirrorsDockAutoHide, globalShortcutEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = OverlayConfiguration()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        skinsDock = try container.decodeIfPresent(Bool.self, forKey: .skinsDock) ?? defaults.skinsDock
        showsIndicators = try container.decodeIfPresent(Bool.self, forKey: .showsIndicators) ?? defaults.showsIndicators
        showsBadges = try container.decodeIfPresent(Bool.self, forKey: .showsBadges) ?? defaults.showsBadges
        bouncesOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .bouncesOnLaunch) ?? defaults.bouncesOnLaunch
        iconScale = try container.decodeIfPresent(Double.self, forKey: .iconScale) ?? defaults.iconScale
        pinnedDisplay = try container.decodeIfPresent(String.self, forKey: .pinnedDisplay)
        style = container.decodeEnum(Style.self, forKey: .style) ?? defaults.style
        blurMaterial = container.decodeEnum(BlurMaterial.self, forKey: .blurMaterial) ?? defaults.blurMaterial
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
        heightMode = container.decodeEnum(HeightMode.self, forKey: .heightMode) ?? defaults.heightMode
        heightAdjustment = try container.decodeIfPresent(Double.self, forKey: .heightAdjustment) ?? defaults.heightAdjustment
        customHeight = try container.decodeIfPresent(Double.self, forKey: .customHeight) ?? defaults.customHeight
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        tint = try container.decodeIfPresent(Tint.self, forKey: .tint) ?? defaults.tint
        animationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .animationsEnabled) ?? defaults.animationsEnabled
        mirrorsDockAutoHide = try container.decodeIfPresent(Bool.self, forKey: .mirrorsDockAutoHide) ?? defaults.mirrorsDockAutoHide
        globalShortcutEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalShortcutEnabled) ?? defaults.globalShortcutEnabled
        self = validated()
    }

    // MARK: Validation

    func validated() -> OverlayConfiguration {
        var config = self
        config.opacity = opacity.clamped(to: Self.opacityRange)
        config.heightAdjustment = heightAdjustment.clamped(to: Self.heightAdjustmentRange)
        config.customHeight = customHeight.clamped(to: Self.customHeightRange)
        config.cornerRadius = cornerRadius.clamped(to: Self.cornerRadiusRange)
        config.tint.strength = tint.strength.clamped(to: Self.tintStrengthRange)
        config.iconScale = iconScale.clamped(to: Self.iconScaleRange)
        return config
    }
}

// MARK: - Migration from Max 1.0

extension OverlayConfiguration {

    /// Keys written by Max 1.0, one UserDefaults entry per setting.
    nonisolated static let legacyKeys = [
        "overlayHeight", "overlayOpacity", "overlayMaterial", "overlayEnabled", "overlayBlendingMode",
        "backgroundOpacity", "useCustomColor", "customColor", "useGradient", "animationsEnabled",
    ]

    /// Builds a configuration from the Max 1.0 per-key layout. Returns nil when none of those keys are present.
    init?(legacyDefaults values: [String: Any], legacyColor: RGBAColor?) {
        guard Self.legacyKeys.contains(where: { values[$0] != nil }) else { return nil }
        var config = OverlayConfiguration()
        if let enabled = values["overlayEnabled"] as? Bool { config.isEnabled = enabled }
        if let opacity = values["overlayOpacity"] as? Double { config.opacity = opacity }
        if let height = values["overlayHeight"] as? Double { config.customHeight = height }
        if let index = values["overlayMaterial"] as? Int, BlurMaterial.legacyOrder.indices.contains(index) {
            config.blurMaterial = BlurMaterial.legacyOrder[index]
        }
        if let useCustomColor = values["useCustomColor"] as? Bool { config.tint.isEnabled = useCustomColor }
        if let legacyColor { config.tint.color = legacyColor }
        if let strength = values["backgroundOpacity"] as? Double { config.tint.strength = strength }
        if let gradient = values["useGradient"] as? Bool { config.tint.fadesUpward = gradient }
        if let animations = values["animationsEnabled"] as? Bool { config.animationsEnabled = animations }
        self = config.validated()
    }
}

private extension KeyedDecodingContainer {
    /// Decodes a raw-representable enum, treating unknown raw values like a missing key.
    nonisolated func decodeEnum<T: RawRepresentable>(_ type: T.Type, forKey key: Key) -> T? where T.RawValue == String {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        return T(rawValue: raw)
    }
}
