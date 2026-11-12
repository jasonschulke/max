import Foundation
import CoreGraphics

/// One entry the user keeps in the Dock.
nonisolated enum DockItem: Codable, Equatable, Sendable {
    case app(url: URL, bundleID: String?)
    /// A folder or file, opened in Finder.
    case folder(url: URL)
    case spacer
    case smallSpacer
}

/// The items the user keeps: apps before the separator, folders after it, as in Apple's Dock.
/// Imported once from `com.apple.dock`, then owned by Max. Finder is never stored; it always leads.
nonisolated struct DockItems: Codable, Equatable, Sendable {
    enum Section: Sendable {
        case apps, others
    }

    var apps: [DockItem] = []
    var others: [DockItem] = []

    static let finderBundleID = "com.apple.finder"
    static let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    init(apps: [DockItem] = [], others: [DockItem] = []) {
        self.apps = apps.filter { !Self.isFinder($0) }
        self.others = others
    }

    /// Builds the list from the `persistent-apps` and `persistent-others` arrays of `com.apple.dock`.
    init(dockApps: [[String: Any]], dockOthers: [[String: Any]]) {
        self.init(apps: dockApps.compactMap(Self.item(fromTile:)), others: dockOthers.compactMap(Self.item(fromTile:)))
    }

    /// One `com.apple.dock` tile. Tiles Max cannot show (web links, recents) come back nil.
    static func item(fromTile tile: [String: Any]) -> DockItem? {
        switch tile["tile-type"] as? String {
        case "spacer-tile":
            return .spacer
        case "small-spacer-tile":
            return .smallSpacer
        case "file-tile", "directory-tile":
            guard let data = tile["tile-data"] as? [String: Any],
                  let fileData = data["file-data"] as? [String: Any],
                  let string = fileData["_CFURLString"] as? String else { return nil }
            // String type 0 is a POSIX path, 15 a URL string.
            let isPath = (fileData["_CFURLStringType"] as? NSNumber)?.intValue == 0
            guard let url = isPath ? URL(fileURLWithPath: string) : URL(string: string), url.isFileURL else { return nil }
            if url.pathExtension == "app" {
                return .app(url: url, bundleID: data["bundle-identifier"] as? String)
            }
            return .folder(url: url)
        default:
            return nil
        }
    }

    static func isFinder(_ item: DockItem) -> Bool {
        if case .app(let url, let bundleID) = item {
            return bundleID == finderBundleID || url.standardizedFileURL.path == finderURL.path
        }
        return false
    }

    func items(in section: Section) -> [DockItem] {
        section == .apps ? apps : others
    }

    /// Moves an item within a section. `destination` is its index once the move is done.
    mutating func move(in section: Section, from source: Int, to destination: Int) {
        var list = items(in: section)
        guard list.indices.contains(source) else { return }
        let item = list.remove(at: source)
        list.insert(item, at: min(max(0, destination), list.count))
        if section == .apps { apps = list } else { others = list }
    }

    mutating func remove(in section: Section, at index: Int) {
        if section == .apps, apps.indices.contains(index) { apps.remove(at: index) }
        if section == .others, others.indices.contains(index) { others.remove(at: index) }
    }

    /// Keeps an app at `index` among the apps, unless it is Finder or already kept.
    mutating func keep(_ item: DockItem, at index: Int? = nil) {
        guard case .app(let url, let bundleID) = item, !Self.isFinder(item) else { return }
        let alreadyKept = apps.contains {
            guard case .app(let keptURL, let keptID) = $0 else { return false }
            return RunningApp.matches(bundleID: keptID, url: keptURL, otherBundleID: bundleID, otherURL: url)
        }
        guard !alreadyKept else { return }
        apps.insert(item, at: min(max(0, index ?? apps.count), apps.count))
    }
}

/// A running app with a Dock presence, as NSWorkspace reports it.
nonisolated struct RunningApp: Equatable, Sendable {
    var processID: Int32
    var bundleID: String?
    var url: URL?
    var name: String
    var isActive = false

    func matches(bundleID: String?, url: URL?) -> Bool {
        Self.matches(bundleID: self.bundleID, url: self.url, otherBundleID: bundleID, otherURL: url)
    }

    /// Bundle identifiers win when both sides have one: an app's path can differ between the Dock and the running copy.
    static func matches(bundleID: String?, url: URL?, otherBundleID: String?, otherURL: URL?) -> Bool {
        if let bundleID, let otherBundleID { return bundleID == otherBundleID }
        guard let url, let otherURL else { return false }
        return url.standardizedFileURL.path == otherURL.standardizedFileURL.path
    }
}

/// One slot on Max's Dock, ready to draw.
nonisolated struct DockTile: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case app, folder, trash, spacer, smallSpacer, separator
    }

    /// Where a kept tile lives in `DockItems`.
    struct Source: Equatable, Sendable {
        var section: DockItems.Section
        var index: Int
    }

    var kind: Kind
    var url: URL?
    var bundleID: String?
    var title = ""
    /// Set while the app runs.
    var processID: Int32?
    var isActive = false
    /// Nil for Finder, running apps the user does not keep, the separator, and the Trash.
    var source: Source?

    var isRunning: Bool { processID != nil }
    var isFinder: Bool { bundleID == DockItems.finderBundleID }
    var isKept: Bool { source != nil || isFinder }

    /// Finder, the kept apps, running apps not kept, the separator, the kept folders, then the Trash.
    static func tiles(items: DockItems, running: [RunningApp], trashURL: URL, displayName: (URL) -> String) -> [DockTile] {
        var unclaimed = running
        func claim(bundleID: String?, url: URL?) -> RunningApp? {
            guard let index = unclaimed.firstIndex(where: { $0.matches(bundleID: bundleID, url: url) }) else { return nil }
            return unclaimed.remove(at: index)
        }
        func app(url: URL?, bundleID: String?, running: RunningApp?, source: Source?) -> DockTile {
            DockTile(
                kind: .app, url: url ?? running?.url, bundleID: bundleID ?? running?.bundleID,
                title: running?.name ?? url.map(displayName) ?? "",
                processID: running?.processID, isActive: running?.isActive ?? false, source: source
            )
        }
        func tile(for item: DockItem, source: Source) -> DockTile {
            switch item {
            case .app(let url, let bundleID):
                return app(url: url, bundleID: bundleID, running: claim(bundleID: bundleID, url: url), source: source)
            case .folder(let url):
                return DockTile(kind: .folder, url: url, title: displayName(url), source: source)
            case .spacer:
                return DockTile(kind: .spacer, source: source)
            case .smallSpacer:
                return DockTile(kind: .smallSpacer, source: source)
            }
        }

        let finder = claim(bundleID: DockItems.finderBundleID, url: DockItems.finderURL)
        var tiles = [app(url: DockItems.finderURL, bundleID: DockItems.finderBundleID, running: finder, source: nil)]
        tiles += items.apps.enumerated().map { tile(for: $1, source: Source(section: .apps, index: $0)) }
        tiles += unclaimed.map { app(url: nil, bundleID: nil, running: $0, source: nil) }
        tiles.append(DockTile(kind: .separator))
        tiles += items.others.enumerated().map { tile(for: $1, source: Source(section: .others, index: $0)) }
        tiles.append(DockTile(kind: .trash, url: trashURL, title: "Trash"))
        return tiles
    }
}

/// Where each tile sits on the bar. Tiles run along the bar (left to right, or top to bottom on a side Dock)
/// and shrink together when they do not fit, as Apple's Dock does.
nonisolated struct DockLayout {
    /// Gap between icons, as a fraction of the icon size.
    static let spacing = 0.2
    /// Room kept at each end of the bar, in points.
    static let endMargin = 8.0
    /// Room kept between the icons and the bar's long edges, for the running indicator.
    static let edgeMargin = 6.0
    /// Distance of the running indicator's center from the screen edge.
    static let indicatorInset = 3.0

    let orientation: DockOrientation
    let bounds: CGRect
    let iconSize: Double
    /// Each tile's full slot: one step along the bar, the bar's whole thickness across it.
    let slots: [CGRect]
    /// Each tile's icon square, centered in its slot.
    let icons: [CGRect]

    static func units(for kind: DockTile.Kind) -> Double {
        switch kind {
        case .smallSpacer, .separator: 0.5
        default: 1
        }
    }

    init(kinds: [DockTile.Kind], bounds: CGRect, orientation: DockOrientation, preferredIconSize: Double) {
        self.orientation = orientation
        self.bounds = bounds
        let vertical = orientation != .bottom
        let length = Double(vertical ? bounds.height : bounds.width)
        let thickness = Double(vertical ? bounds.width : bounds.height)
        let units = kinds.map(Self.units).reduce(0, +)
        let fitting = units > 0 ? (length - 2 * Self.endMargin) / (units * (1 + Self.spacing)) : preferredIconSize
        let size = max(1, min(preferredIconSize, thickness - 2 * Self.edgeMargin, fitting))
        iconSize = size

        let step = size * (1 + Self.spacing)
        // Centered along the bar; a side Dock starts at the top.
        var cursor = (length - units * step) / 2
        var slots: [CGRect] = []
        var icons: [CGRect] = []
        for kind in kinds {
            let advance = Self.units(for: kind) * step
            let slot: CGRect
            if vertical {
                slot = CGRect(x: bounds.minX, y: bounds.maxY - cursor - advance, width: bounds.width, height: advance)
            } else {
                slot = CGRect(x: bounds.minX + cursor, y: bounds.minY, width: advance, height: bounds.height)
            }
            slots.append(slot)
            let side = min(size, Double(vertical ? slot.height : slot.width))
            icons.append(CGRect(x: slot.midX - side / 2, y: slot.midY - side / 2, width: side, height: side))
            cursor += advance
        }
        self.slots = slots
        self.icons = icons
    }

    /// Index of the slot under a point, if any.
    func slot(at point: CGPoint) -> Int? {
        slots.firstIndex { $0.contains(point) }
    }

    /// How far along the bar a point is: grows left to right, or top to bottom on a side Dock.
    func position(of point: CGPoint) -> Double {
        orientation == .bottom ? Double(point.x) : Double(bounds.maxY - point.y)
    }

    /// Where a tile dropped at `point` lands among `slotIndices`: the number of them whose center comes before it.
    func insertionIndex(at point: CGPoint, among slotIndices: [Int]) -> Int {
        let target = position(of: point)
        return slotIndices.filter { position(of: CGPoint(x: slots[$0].midX, y: slots[$0].midY)) < target }.count
    }

    /// Center of the running indicator for the tile in `slot`: on the screen-edge side, under the icon.
    func indicatorCenter(for slot: Int) -> CGPoint {
        let icon = icons[slot]
        let inset = CGFloat(Self.indicatorInset)
        switch orientation {
        case .bottom: return CGPoint(x: icon.midX, y: bounds.minY + inset)
        case .left: return CGPoint(x: bounds.minX + inset, y: icon.midY)
        case .right: return CGPoint(x: bounds.maxX - inset, y: icon.midY)
        }
    }
}
