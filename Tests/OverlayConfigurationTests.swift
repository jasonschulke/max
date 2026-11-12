import Foundation

let overlayConfigurationTests: [TestCase] = [
    TestCase(name: "defaults match the Dock and use Liquid Glass") {
        let config = OverlayConfiguration()
        expectEqual(config.isEnabled, true)
        expectEqual(config.skinsDock, false)
        expectEqual(config.style, .glass)
        expectEqual(config.heightMode, .matchDock)
        expectEqual(config.opacity, 1.0)
        expectEqual(config.tint.isEnabled, false)
        expectEqual(config.mirrorsDockAutoHide, true)
        expectEqual(config.globalShortcutEnabled, true)
    },
    TestCase(name: "validated() clamps every numeric field into range") {
        var config = OverlayConfiguration()
        config.opacity = 5
        config.heightAdjustment = -500
        config.customHeight = 1
        config.cornerRadius = 99
        config.tint.strength = -1
        let valid = config.validated()
        expectEqual(valid.opacity, OverlayConfiguration.opacityRange.upperBound)
        expectEqual(valid.heightAdjustment, OverlayConfiguration.heightAdjustmentRange.lowerBound)
        expectEqual(valid.customHeight, OverlayConfiguration.customHeightRange.lowerBound)
        expectEqual(valid.cornerRadius, OverlayConfiguration.cornerRadiusRange.upperBound)
        expectEqual(valid.tint.strength, 0)
    },
    TestCase(name: "JSON round trip preserves every field") {
        var config = OverlayConfiguration()
        config.isEnabled = false
        config.skinsDock = true
        config.style = .blur
        config.blurMaterial = .hudWindow
        config.opacity = 0.42
        config.heightMode = .custom
        config.customHeight = 77
        config.heightAdjustment = 12
        config.cornerRadius = 9
        config.tint = .init(isEnabled: true, color: RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1), strength: 0.3, fadesUpward: true)
        config.animationsEnabled = false
        config.mirrorsDockAutoHide = false
        config.globalShortcutEnabled = false
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(OverlayConfiguration.self, from: data)
        expectEqual(decoded, config)
    },
    TestCase(name: "decoding JSON with missing keys falls back to defaults") {
        let json = Data(#"{"isEnabled": false, "opacity": 0.5}"#.utf8)
        let decoded = try JSONDecoder().decode(OverlayConfiguration.self, from: json)
        expectEqual(decoded.isEnabled, false)
        expectEqual(decoded.opacity, 0.5)
        expectEqual(decoded.style, .glass)
        expectEqual(decoded.tint, OverlayConfiguration.Tint())
    },
    TestCase(name: "decoding an unknown style value falls back to the default") {
        let json = Data(#"{"style": "neon"}"#.utf8)
        let decoded = try JSONDecoder().decode(OverlayConfiguration.self, from: json)
        expectEqual(decoded.style, .glass)
    },
    TestCase(name: "legacy per-key defaults from Max 1.0 migrate") {
        let legacy: [String: Any] = [
            "overlayEnabled": true,
            "overlayOpacity": 0.5567,
            "overlayHeight": 20.0,
            "overlayMaterial": 7,
            "useCustomColor": true,
            "backgroundOpacity": 0.85,
            "useGradient": true,
            "animationsEnabled": false,
        ]
        let color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        guard let migrated = OverlayConfiguration(legacyDefaults: legacy, legacyColor: color) else {
            expect(false, "migration returned nil"); return
        }
        expectEqual(migrated.isEnabled, true)
        expectClose(migrated.opacity, 0.5567)
        expectEqual(migrated.customHeight, 20)
        expectEqual(migrated.heightMode, .matchDock)
        expectEqual(migrated.blurMaterial, .hudWindow)
        expectEqual(migrated.tint.isEnabled, true)
        expectEqual(migrated.tint.color, color)
        expectClose(migrated.tint.strength, 0.85)
        expectEqual(migrated.tint.fadesUpward, true)
        expectEqual(migrated.animationsEnabled, false)
    },
    TestCase(name: "legacy migration returns nil when no legacy keys exist") {
        expect(OverlayConfiguration(legacyDefaults: ["unrelated": 1], legacyColor: nil) == nil)
    },
    TestCase(name: "RGBAColor clamps components") {
        let color = RGBAColor(red: 2, green: -1, blue: 0.5, alpha: 3)
        expectEqual(color, RGBAColor(red: 1, green: 0, blue: 0.5, alpha: 1))
    },
]
