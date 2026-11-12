import Foundation
import CoreGraphics

private func fileTile(_ url: String, bundleID: String? = nil, type: Int = 15, tileType: String = "file-tile") -> [String: Any] {
    var data: [String: Any] = ["file-data": ["_CFURLString": url, "_CFURLStringType": type]]
    if let bundleID { data["bundle-identifier"] = bundleID }
    return ["tile-type": tileType, "tile-data": data]
}

private let safariURL = URL(string: "file:///System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/")!
private let notesURL = URL(fileURLWithPath: "/System/Applications/Notes.app")
private let downloadsURL = URL(fileURLWithPath: "/Users/me/Downloads", isDirectory: true)
private let trashURL = URL(fileURLWithPath: "/Users/me/.Trash", isDirectory: true)
private func name(_ url: URL) -> String { url.deletingPathExtension().lastPathComponent }

let dockItemsTests: [TestCase] = [
    TestCase(name: "Dock tiles parse into apps, folders, and spacers") {
        expectEqual(DockItems.item(fromTile: fileTile(safariURL.absoluteString, bundleID: "com.apple.Safari")),
                    .app(url: safariURL, bundleID: "com.apple.Safari"))
        expectEqual(DockItems.item(fromTile: fileTile("/Applications/Foo.app", type: 0)),
                    .app(url: URL(fileURLWithPath: "/Applications/Foo.app"), bundleID: nil))
        expectEqual(DockItems.item(fromTile: fileTile("file:///Users/me/Downloads/", tileType: "directory-tile")),
                    .folder(url: URL(string: "file:///Users/me/Downloads/")!))
        expectEqual(DockItems.item(fromTile: ["tile-type": "spacer-tile", "tile-data": ["file-label": ""]]), .spacer)
        expectEqual(DockItems.item(fromTile: ["tile-type": "small-spacer-tile"]), .smallSpacer)
        expect(DockItems.item(fromTile: ["tile-type": "url-tile"]) == nil, "web links are skipped")
        expect(DockItems.item(fromTile: fileTile("https://example.com")) == nil, "non-file URLs are skipped")
    },
    TestCase(name: "Finder is never stored; it always leads") {
        let items = DockItems(apps: [.app(url: DockItems.finderURL, bundleID: DockItems.finderBundleID), .spacer])
        expectEqual(items.apps, [.spacer])
        var kept = DockItems()
        kept.keep(.app(url: DockItems.finderURL, bundleID: nil))
        expectEqual(kept.apps, [])
    },
    TestCase(name: "keeping an app skips one already kept and clamps the index") {
        var items = DockItems(apps: [.app(url: safariURL, bundleID: "com.apple.Safari")])
        items.keep(.app(url: URL(fileURLWithPath: "/Applications/Safari.app"), bundleID: "com.apple.Safari"))
        expectEqual(items.apps.count, 1)
        items.keep(.app(url: notesURL, bundleID: "com.apple.Notes"), at: 99)
        expectEqual(items.apps.last, .app(url: notesURL, bundleID: "com.apple.Notes"))
        items.keep(.spacer)
        expectEqual(items.apps.count, 2)
    },
    TestCase(name: "moving and removing within a section") {
        var items = DockItems(apps: [.spacer, .app(url: notesURL, bundleID: nil), .smallSpacer])
        items.move(in: .apps, from: 0, to: 2)
        expectEqual(items.apps, [.app(url: notesURL, bundleID: nil), .smallSpacer, .spacer])
        items.move(in: .apps, from: 2, to: 0)
        expectEqual(items.apps, [.spacer, .app(url: notesURL, bundleID: nil), .smallSpacer])
        items.remove(in: .apps, at: 1)
        expectEqual(items.apps, [.spacer, .smallSpacer])
        items.remove(in: .others, at: 0)
        expectEqual(items.others, [])
    },
    TestCase(name: "tiles: Finder, kept apps, other running apps, separator, folders, Trash") {
        let items = DockItems(apps: [.app(url: safariURL, bundleID: "com.apple.Safari"), .spacer, .app(url: notesURL, bundleID: "com.apple.Notes")],
                              others: [.folder(url: downloadsURL)])
        let running = [
            RunningApp(processID: 1, bundleID: "com.apple.finder", url: DockItems.finderURL, name: "Finder"),
            RunningApp(processID: 2, bundleID: "com.apple.Terminal", url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), name: "Terminal", isActive: true),
            // Safari runs from /Applications while the Dock stores its cryptex path: the bundle identifier still matches.
            RunningApp(processID: 3, bundleID: "com.apple.Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"), name: "Safari"),
        ]
        let tiles = DockTile.tiles(items: items, running: running, trashURL: trashURL, displayName: name)
        expectEqual(tiles.map(\.kind), [.app, .app, .spacer, .app, .app, .separator, .folder, .trash])
        expectEqual(tiles.map(\.title), ["Finder", "Safari", "", "Notes", "Terminal", "", "Downloads", "Trash"])
        expectEqual(tiles.map(\.processID), [1, 3, nil, nil, 2, nil, nil, nil])
        expectEqual(tiles[0].isKept, true)
        expectEqual(tiles[1].source, DockTile.Source(section: .apps, index: 0))
        expectEqual(tiles[3].source, DockTile.Source(section: .apps, index: 2))
        expectEqual(tiles[4].isKept, false)
        expectEqual(tiles[4].isActive, true)
        expectEqual(tiles[6].source, DockTile.Source(section: .others, index: 0))
        expectEqual(tiles[7].url, trashURL)
    },
    TestCase(name: "layout uses the preferred icon size when the tiles fit, centered") {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 50)
        let layout = DockLayout(kinds: [.app, .app], bounds: bounds, orientation: .bottom, preferredIconSize: 30)
        expectClose(layout.iconSize, 30)
        expectClose(Double(layout.slots[0].width), 36)
        expectClose(Double(layout.slots[0].minX), 464)
        expectClose(Double(layout.icons[1].midY), 25)
        expectEqual(layout.slot(at: CGPoint(x: 510, y: 2)), 1)
        expectEqual(layout.slot(at: CGPoint(x: 100, y: 25)), nil)
    },
    TestCase(name: "layout shrinks the icons to fit, like a crowded Dock") {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 50)
        let kinds = [DockTile.Kind](repeating: .app, count: 50)
        let layout = DockLayout(kinds: kinds, bounds: bounds, orientation: .bottom, preferredIconSize: 37)
        expectClose(Double(layout.slots.last!.maxX - layout.slots.first!.minX), 1000 - 2 * DockLayout.endMargin)
        expect(layout.iconSize < 37, "icons shrank to \(layout.iconSize)")
    },
    TestCase(name: "icons never crowd the running indicator") {
        let layout = DockLayout(kinds: [.app], bounds: CGRect(x: 0, y: 0, width: 1000, height: 40), orientation: .bottom, preferredIconSize: 64)
        expectClose(layout.iconSize, 40 - 2 * DockLayout.edgeMargin)
    },
    TestCase(name: "half-width separators and small spacers") {
        let layout = DockLayout(kinds: [.app, .separator, .smallSpacer, .app], bounds: CGRect(x: 0, y: 0, width: 1000, height: 50), orientation: .bottom, preferredIconSize: 30)
        expectClose(Double(layout.slots[1].width), 18)
        expectClose(Double(layout.slots[2].width), 18)
        expectClose(Double(layout.slots[3].minX - layout.slots[0].maxX), 36)
    },
    TestCase(name: "side Docks run top to bottom with the indicator on the screen edge") {
        let bounds = CGRect(x: 0, y: 0, width: 50, height: 600)
        let left = DockLayout(kinds: [.app, .app], bounds: bounds, orientation: .left, preferredIconSize: 30)
        expect(left.slots[0].minY > left.slots[1].minY, "first tile is on top")
        expectEqual(left.indicatorCenter(for: 0), CGPoint(x: DockLayout.indicatorInset, y: left.icons[0].midY))
        let right = DockLayout(kinds: [.app], bounds: bounds, orientation: .right, preferredIconSize: 30)
        expectEqual(right.indicatorCenter(for: 0).x, 50 - DockLayout.indicatorInset)
        let bottom = DockLayout(kinds: [.app], bounds: CGRect(x: 0, y: 0, width: 600, height: 50), orientation: .bottom, preferredIconSize: 30)
        expectEqual(bottom.indicatorCenter(for: 0), CGPoint(x: 300, y: DockLayout.indicatorInset))
    },
    TestCase(name: "insertion index counts the tiles before the pointer") {
        let bottom = DockLayout(kinds: [.app, .app, .app, .app], bounds: CGRect(x: 0, y: 0, width: 1000, height: 50), orientation: .bottom, preferredIconSize: 30)
        let between = CGPoint(x: bottom.slots[2].minX, y: 25)
        expectEqual(bottom.insertionIndex(at: between, among: [0, 1, 2, 3]), 2)
        expectEqual(bottom.insertionIndex(at: CGPoint(x: 0, y: 25), among: [1, 2]), 0)
        let side = DockLayout(kinds: [.app, .app, .app], bounds: CGRect(x: 0, y: 0, width: 50, height: 600), orientation: .left, preferredIconSize: 30)
        expectEqual(side.insertionIndex(at: CGPoint(x: 25, y: side.slots[1].minY), among: [0, 1, 2]), 2)
    },
]
