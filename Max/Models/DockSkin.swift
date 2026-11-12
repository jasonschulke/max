import Foundation
import CoreGraphics

/// One item of Apple's Dock as Accessibility reports it, for Max to draw over.
nonisolated struct SkinItem: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case app, folder, file, trash, minimizedWindow, separator, spacer, other
    }

    var kind: Kind
    var title: String
    var url: URL?
    /// The item's slot in AppKit screen coordinates (origin at the primary display's bottom-left corner).
    var frame: CGRect
    var isRunning = false
    /// The frontmost app.
    var isActive = false
    /// The badge an app shows on its Dock tile, such as an unread count.
    var badge: String?

    /// Whether Max draws anything for the item. Spacers and the space around icons are just bar.
    var isDrawn: Bool {
        switch kind {
        case .spacer, .other: false
        default: true
        }
    }
}

/// Geometry and parsing for skinning Apple's Dock. Measured on macOS 26 and 27.
nonisolated enum DockSkin {
    /// Apple's Dock draws an icon image at this fraction of its slot's length along the Dock, centered in the slot.
    static let iconFraction = 0.9625
    /// The running indicator's center sits this far inside the slot's screen-edge side.
    static let indicatorInset = 6.0

    static func kind(forSubrole subrole: String?) -> SkinItem.Kind {
        switch subrole {
        case "AXApplicationDockItem": .app
        case "AXFolderDockItem": .folder
        case "AXDocumentDockItem", "AXURLDockItem": .file
        case "AXTrashDockItem": .trash
        case "AXMinimizedWindowDockItem": .minimizedWindow
        case "AXSeparatorDockItem": .separator
        case "AXSpacerDockItem": .spacer
        default: .other
        }
    }

    /// Accessibility positions are measured from the primary display's top-left corner, y growing downward.
    static func appKitFrame(axPosition: CGPoint, axSize: CGSize, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: axPosition.x, y: primaryScreenHeight - axPosition.y - axSize.height, width: axSize.width, height: axSize.height)
    }

    /// The square Apple's Dock draws an item's icon image in.
    static func iconFrame(for slot: CGRect, orientation: DockOrientation) -> CGRect {
        let along = orientation == .bottom ? slot.width : slot.height
        let side = min(along * CGFloat(iconFraction), slot.width, slot.height)
        return CGRect(x: slot.midX - side / 2, y: slot.midY - side / 2, width: side, height: side)
    }

    /// Center of the running indicator: inside the slot, on the side facing the screen edge.
    static func indicatorCenter(for slot: CGRect, orientation: DockOrientation) -> CGPoint {
        let inset = CGFloat(indicatorInset)
        switch orientation {
        case .bottom: return CGPoint(x: slot.midX, y: slot.minY + inset)
        case .left: return CGPoint(x: slot.minX + inset, y: slot.midY)
        case .right: return CGPoint(x: slot.maxX - inset, y: slot.midY)
        }
    }

    /// Rounds frames to half points so sub-pixel jitter between Accessibility reads does not count as a change.
    static func settled(_ frame: CGRect) -> CGRect {
        func half(_ value: CGFloat) -> CGFloat { (value * 2).rounded() / 2 }
        return CGRect(x: half(frame.minX), y: half(frame.minY), width: half(frame.width), height: half(frame.height))
    }
}

/// One entry of Apple's Dock preferences (`persistent-apps` / `persistent-others` in `com.apple.dock`).
nonisolated enum DockTile: Equatable, Sendable {
    case app(url: URL, bundleID: String?)
    /// A folder or file, shown on the Dock's right-hand side.
    case folder(url: URL)
    case spacer
    case smallSpacer
    /// Anything else the Dock keeps (web links, recents). Preserved untouched.
    case other(type: String)

    /// Reads one tile dictionary from the Dock's preferences.
    init(preferences tile: [String: Any]) {
        let type = tile["tile-type"] as? String ?? ""
        switch type {
        case "spacer-tile":
            self = .spacer
        case "small-spacer-tile":
            self = .smallSpacer
        case "file-tile", "directory-tile":
            guard let data = tile["tile-data"] as? [String: Any],
                  let fileData = data["file-data"] as? [String: Any],
                  let string = fileData["_CFURLString"] as? String,
                  // String type 0 is a POSIX path, 15 a URL string.
                  let url = (fileData["_CFURLStringType"] as? NSNumber)?.intValue == 0 ? URL(fileURLWithPath: string) : URL(string: string),
                  url.isFileURL else {
                self = .other(type: type)
                return
            }
            self = url.pathExtension == "app" ? .app(url: url, bundleID: data["bundle-identifier"] as? String) : .folder(url: url)
        default:
            self = .other(type: type)
        }
    }

    /// A tile dictionary for the Dock's preferences. The Dock fills in the rest when it loads.
    var preferences: [String: Any] {
        func file(_ url: URL, type: String, data extra: [String: Any]) -> [String: Any] {
            var data: [String: Any] = [
                "file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15],
                "file-label": url.deletingPathExtension().lastPathComponent,
            ]
            data.merge(extra) { _, new in new }
            return ["tile-type": type, "tile-data": data]
        }
        switch self {
        case .app(let url, let bundleID):
            return file(url, type: "file-tile", data: bundleID.map { ["bundle-identifier": $0] } ?? [:])
        case .folder(let url):
            // Shown as a folder icon, opening as a grid, sorted by name.
            return file(url, type: "directory-tile", data: ["displayas": 1, "showas": 2, "arrangement": 1])
        case .spacer:
            return ["tile-type": "spacer-tile", "tile-data": [:] as [String: Any]]
        case .smallSpacer:
            return ["tile-type": "small-spacer-tile", "tile-data": [:] as [String: Any]]
        case .other(let type):
            return ["tile-type": type]
        }
    }
}
