import Foundation
import CoreGraphics

private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
private let visibleBottomDock = CGRect(x: 0, y: 50, width: 1920, height: 1000)   // measured on a 1080p display, tilesize 37
private let visibleNoDock = CGRect(x: 0, y: 0, width: 1920, height: 1050)        // auto-hide: only the menu bar is reserved
private let visibleLeftDock = CGRect(x: 60, y: 0, width: 1860, height: 1050)
private let visibleRightDock = CGRect(x: 0, y: 0, width: 1860, height: 1050)

let dockGeometryTests: [TestCase] = [
    TestCase(name: "DockInfo parses the com.apple.dock preference keys") {
        let info = DockInfo(preferences: ["orientation": "left", "autohide": true, "tilesize": 37.0, "autohide-delay": 0.2, "autohide-time-modifier": 0.3])
        expectEqual(info.orientation, .left)
        expectEqual(info.autoHides, true)
        expectEqual(info.tileSize, 37)
        expectClose(info.autoHideDelay, 0.2)
        expectClose(info.autoHideDuration, 0.3)
    },
    TestCase(name: "DockInfo falls back to defaults for missing or odd values") {
        let info = DockInfo(preferences: ["orientation": "sideways", "autohide": 1, "tilesize": "big"])
        expectEqual(info.orientation, .bottom)
        expectEqual(info.autoHides, true)
        expectEqual(info.tileSize, DockInfo.defaultTileSize)
        expectEqual(DockInfo(preferences: [:]), DockInfo())
    },
    TestCase(name: "reserved thickness comes from the gap between frame and visibleFrame") {
        expectEqual(DockGeometry.reservedThickness(screenFrame: screen, visibleFrame: visibleBottomDock, orientation: .bottom), 50)
        expectEqual(DockGeometry.reservedThickness(screenFrame: screen, visibleFrame: visibleLeftDock, orientation: .left), 60)
        expectEqual(DockGeometry.reservedThickness(screenFrame: screen, visibleFrame: visibleRightDock, orientation: .right), 60)
        expectEqual(DockGeometry.reservedThickness(screenFrame: screen, visibleFrame: visibleNoDock, orientation: .bottom), 0)
    },
    TestCase(name: "estimated thickness reproduces the measured Dock strip") {
        expectEqual(DockGeometry.estimatedThickness(tileSize: 37), 50)
    },
    TestCase(name: "matchDock thickness uses the reserved strip plus the adjustment") {
        var config = OverlayConfiguration()
        config.heightAdjustment = 10
        let dock = DockInfo()
        let thickness = DockGeometry.thickness(configuration: config, dock: dock, screenFrame: screen, visibleFrame: visibleBottomDock)
        expectEqual(thickness, 60)
    },
    TestCase(name: "matchDock thickness falls back to the tilesize estimate when the Dock auto-hides") {
        let config = OverlayConfiguration()
        let dock = DockInfo(preferences: ["autohide": true, "tilesize": 37.0])
        let thickness = DockGeometry.thickness(configuration: config, dock: dock, screenFrame: screen, visibleFrame: visibleNoDock)
        expectEqual(thickness, 50)
    },
    TestCase(name: "custom thickness ignores the Dock entirely") {
        var config = OverlayConfiguration()
        config.heightMode = .custom
        config.customHeight = 120
        config.heightAdjustment = 40
        let thickness = DockGeometry.thickness(configuration: config, dock: DockInfo(), screenFrame: screen, visibleFrame: visibleBottomDock)
        expectEqual(thickness, 120)
    },
    TestCase(name: "thickness never drops below one point") {
        var config = OverlayConfiguration()
        config.heightAdjustment = -40
        let dock = DockInfo(preferences: ["autohide": true, "tilesize": 16.0])
        let thickness = DockGeometry.thickness(configuration: config, dock: dock, screenFrame: screen, visibleFrame: visibleNoDock)
        expect(thickness >= 1, "thickness was \(thickness)")
    },
    TestCase(name: "bottom overlay spans the screen width and extends below it by the corner radius") {
        let frame = DockGeometry.overlayFrame(thickness: 50, cornerRadius: 8, orientation: .bottom, screenFrame: screen, visibleFrame: visibleBottomDock)
        expectEqual(frame, CGRect(x: 0, y: -8, width: 1920, height: 58))
    },
    TestCase(name: "left overlay spans up to the menu bar and extends past the left edge") {
        let frame = DockGeometry.overlayFrame(thickness: 60, cornerRadius: 8, orientation: .left, screenFrame: screen, visibleFrame: visibleLeftDock)
        expectEqual(frame, CGRect(x: -8, y: 0, width: 68, height: 1050))
    },
    TestCase(name: "right overlay hugs the right edge") {
        let frame = DockGeometry.overlayFrame(thickness: 60, cornerRadius: 0, orientation: .right, screenFrame: screen, visibleFrame: visibleRightDock)
        expectEqual(frame, CGRect(x: 1860, y: 0, width: 60, height: 1050))
    },
    TestCase(name: "overlay frames respect a screen whose origin is not zero") {
        let offsetScreen = CGRect(x: 1920, y: -540, width: 960, height: 540)
        let visible = CGRect(x: 1920, y: -500, width: 960, height: 475)
        let frame = DockGeometry.overlayFrame(thickness: 40, cornerRadius: 0, orientation: .bottom, screenFrame: offsetScreen, visibleFrame: visible)
        expectEqual(frame, CGRect(x: 1920, y: -540, width: 960, height: 40))
    },
    TestCase(name: "pointer hit-testing for auto-hide reveal and dismissal") {
        let zone = DockGeometry.revealZone(orientation: .bottom, screenFrame: screen, thickness: 50)
        expect(zone.triggers(CGPoint(x: 500, y: 0)), "pointer on the bottom edge should trigger")
        expect(!zone.triggers(CGPoint(x: 500, y: 3)), "pointer 3pt above the edge should not trigger")
        expect(zone.contains(CGPoint(x: 500, y: 40)), "pointer inside the strip keeps it revealed")
        expect(!zone.contains(CGPoint(x: 500, y: 80)), "pointer above the strip dismisses")
        expect(!zone.triggers(CGPoint(x: 2500, y: 0)), "pointer on another display should not trigger")
        let left = DockGeometry.revealZone(orientation: .left, screenFrame: screen, thickness: 60)
        expect(left.triggers(CGPoint(x: 0, y: 500)))
        expect(left.contains(CGPoint(x: 50, y: 500)))
        expect(!left.contains(CGPoint(x: 90, y: 500)))
    },
]
