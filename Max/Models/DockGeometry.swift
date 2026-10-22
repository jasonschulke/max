import Foundation
import CoreGraphics

nonisolated enum DockOrientation: String, Sendable {
    case bottom, left, right
}

/// What we can learn about the Dock from its preferences domain (`com.apple.dock`).
nonisolated struct DockInfo: Equatable, Sendable {
    /// Icon size the Dock uses when `tilesize` was never customized.
    static let defaultTileSize = 48.0
    /// The Dock's own defaults for the auto-hide reveal delay and slide duration.
    static let defaultAutoHideDelay = 0.5
    static let defaultAutoHideDuration = 0.5

    var orientation: DockOrientation = .bottom
    var autoHides = false
    var tileSize = DockInfo.defaultTileSize
    var autoHideDelay = DockInfo.defaultAutoHideDelay
    var autoHideDuration = DockInfo.defaultAutoHideDuration

    init() {}

    init(preferences: [String: Any]) {
        if let raw = preferences["orientation"] as? String, let parsed = DockOrientation(rawValue: raw) {
            orientation = parsed
        }
        if let flag = preferences["autohide"] as? Bool {
            autoHides = flag
        } else if let number = preferences["autohide"] as? NSNumber {
            autoHides = number.boolValue
        }
        if let size = (preferences["tilesize"] as? NSNumber)?.doubleValue, size > 0 {
            tileSize = size
        }
        if let delay = (preferences["autohide-delay"] as? NSNumber)?.doubleValue, delay >= 0 {
            autoHideDelay = delay
        }
        if let duration = (preferences["autohide-time-modifier"] as? NSNumber)?.doubleValue, duration >= 0 {
            autoHideDuration = duration
        }
    }
}

/// Pure geometry for placing the bar over the Dock's strip of the primary display.
nonisolated enum DockGeometry {

    /// Measured on macOS 26 with a bottom Dock: tilesize 37 reserves a 50 pt strip.
    static let pillPadding = 13.0

    /// The strip macOS keeps clear for the Dock: the gap between `frame` and `visibleFrame` on the Dock's edge.
    /// Zero when the Dock auto-hides (or lives on another display).
    static func reservedThickness(screenFrame: CGRect, visibleFrame: CGRect, orientation: DockOrientation) -> Double {
        let gap: CGFloat
        switch orientation {
        case .bottom: gap = visibleFrame.minY - screenFrame.minY
        case .left: gap = visibleFrame.minX - screenFrame.minX
        case .right: gap = screenFrame.maxX - visibleFrame.maxX
        }
        return Double(max(0, gap))
    }

    /// Best guess at the Dock's thickness when the strip is not reserved (auto-hide).
    static func estimatedThickness(tileSize: Double) -> Double {
        tileSize + pillPadding
    }

    /// The bar's thickness for a configuration, before the off-screen corner extension.
    static func thickness(configuration: OverlayConfiguration, dock: DockInfo, screenFrame: CGRect, visibleFrame: CGRect) -> Double {
        let resolved: Double
        switch configuration.heightMode {
        case .custom:
            resolved = configuration.customHeight
        case .matchDock:
            let reserved = reservedThickness(screenFrame: screenFrame, visibleFrame: visibleFrame, orientation: dock.orientation)
            let base = reserved > 0 ? reserved : estimatedThickness(tileSize: dock.tileSize)
            resolved = base + configuration.heightAdjustment
        }
        return max(1, resolved)
    }

    /// Window frame for the bar. The edge against the screen border is pushed `cornerRadius` points
    /// off-screen so only the corners facing into the screen are visibly rounded.
    static func overlayFrame(thickness: Double, cornerRadius: Double, orientation: DockOrientation, screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let thickness = CGFloat(thickness)
        let radius = CGFloat(max(0, cornerRadius))
        // Vertical Docks stop below the menu bar.
        let sideHeight = visibleFrame.maxY - screenFrame.minY
        switch orientation {
        case .bottom:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY - radius, width: screenFrame.width, height: thickness + radius)
        case .left:
            return CGRect(x: screenFrame.minX - radius, y: screenFrame.minY, width: thickness + radius, height: sideHeight)
        case .right:
            return CGRect(x: screenFrame.maxX - thickness, y: screenFrame.minY, width: thickness + radius, height: sideHeight)
        }
    }

    /// Pointer regions used to mirror the Dock's auto-hide behavior.
    struct RevealZone: Equatable, Sendable {
        /// Touching this edge strip (a couple of points deep) reveals the Dock.
        var trigger: CGRect
        /// Leaving this region dismisses it again.
        var strip: CGRect

        func triggers(_ point: CGPoint) -> Bool { trigger.contains(point) }
        func contains(_ point: CGPoint) -> Bool { strip.contains(point) }
    }

    static func revealZone(orientation: DockOrientation, screenFrame: CGRect, thickness: Double, edgeDepth: Double = 2) -> RevealZone {
        let depth = CGFloat(edgeDepth)
        // A little slack so the bar does not flicker while the pointer rides its top edge.
        let stripDepth = CGFloat(thickness) + 4
        switch orientation {
        case .bottom:
            return RevealZone(
                trigger: CGRect(x: screenFrame.minX, y: screenFrame.minY - 1, width: screenFrame.width, height: depth + 1),
                strip: CGRect(x: screenFrame.minX, y: screenFrame.minY - 1, width: screenFrame.width, height: stripDepth + 1)
            )
        case .left:
            return RevealZone(
                trigger: CGRect(x: screenFrame.minX - 1, y: screenFrame.minY, width: depth + 1, height: screenFrame.height),
                strip: CGRect(x: screenFrame.minX - 1, y: screenFrame.minY, width: stripDepth + 1, height: screenFrame.height)
            )
        case .right:
            return RevealZone(
                trigger: CGRect(x: screenFrame.maxX - depth, y: screenFrame.minY, width: depth + 1, height: screenFrame.height),
                strip: CGRect(x: screenFrame.maxX - stripDepth, y: screenFrame.minY, width: stripDepth + 1, height: screenFrame.height)
            )
        }
    }
}
