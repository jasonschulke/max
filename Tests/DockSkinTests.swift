import Foundation
import CoreGraphics

private func fileTile(_ url: String, bundleID: String? = nil, type: Int = 15, tileType: String = "file-tile") -> [String: Any] {
    var data: [String: Any] = ["file-data": ["_CFURLString": url, "_CFURLStringType": type]]
    if let bundleID { data["bundle-identifier"] = bundleID }
    return ["tile-type": tileType, "tile-data": data]
}

let dockSkinTests: [TestCase] = [
    TestCase(name: "Accessibility subroles map to item kinds") {
        expectEqual(DockSkin.kind(forSubrole: "AXApplicationDockItem"), .app)
        expectEqual(DockSkin.kind(forSubrole: "AXFolderDockItem"), .folder)
        expectEqual(DockSkin.kind(forSubrole: "AXTrashDockItem"), .trash)
        expectEqual(DockSkin.kind(forSubrole: "AXSeparatorDockItem"), .separator)
        expectEqual(DockSkin.kind(forSubrole: "AXSpacerDockItem"), .spacer)
        expectEqual(DockSkin.kind(forSubrole: "AXMinimizedWindowDockItem"), .minimizedWindow)
        expectEqual(DockSkin.kind(forSubrole: nil), .other)
    },
    TestCase(name: "Accessibility positions flip into AppKit screen coordinates") {
        // Finder in a crowded bottom Dock on a 1080-point display, as the Dock reports it.
        let frame = DockSkin.appKitFrame(axPosition: CGPoint(x: 25.96, y: 1031.04), axSize: CGSize(width: 31.96, height: 43.96), primaryScreenHeight: 1080)
        expectClose(Double(frame.minY), 5)
        expectClose(Double(frame.maxY), 48.96)
        expectClose(Double(frame.minX), 25.96)
    },
    TestCase(name: "icons sit centered in their slot at the Dock's size") {
        let slot = CGRect(x: 25.96, y: 5, width: 31.96, height: 43.96)
        let icon = DockSkin.iconFrame(for: slot, orientation: .bottom)
        // The visible icon is 80.5% of the image: about 24.8 pt, as measured on screen.
        expectClose(Double(icon.width) * 0.8047, 24.75, tolerance: 0.05)
        expectClose(Double(icon.midX), Double(slot.midX))
        expectClose(Double(icon.midY), Double(slot.midY))
        let side = DockSkin.iconFrame(for: CGRect(x: 0, y: 100, width: 44, height: 32), orientation: .left)
        expectClose(Double(side.width), 32 * DockSkin.iconFraction)
    },
    TestCase(name: "running indicators sit on the slot's screen-edge side") {
        let slot = CGRect(x: 10, y: 5, width: 32, height: 44)
        expectEqual(DockSkin.indicatorCenter(for: slot, orientation: .bottom), CGPoint(x: 26, y: 11))
        let side = CGRect(x: 0, y: 100, width: 44, height: 32)
        expectEqual(DockSkin.indicatorCenter(for: side, orientation: .left), CGPoint(x: 6, y: 116))
        expectEqual(DockSkin.indicatorCenter(for: side, orientation: .right), CGPoint(x: 38, y: 116))
    },
    TestCase(name: "frames settle to half points") {
        expectEqual(DockSkin.settled(CGRect(x: 25.96, y: 5.1, width: 31.96, height: 43.96)), CGRect(x: 26, y: 5, width: 32, height: 44))
    },
    TestCase(name: "Dock preference tiles parse into apps, folders, spacers, and others") {
        let safari = "file:///System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/"
        expectEqual(DockTile(preferences: fileTile(safari, bundleID: "com.apple.Safari")), .app(url: URL(string: safari)!, bundleID: "com.apple.Safari"))
        expectEqual(DockTile(preferences: fileTile("/Applications/Foo.app", type: 0)), .app(url: URL(fileURLWithPath: "/Applications/Foo.app"), bundleID: nil))
        expectEqual(DockTile(preferences: fileTile("file:///Users/me/Downloads/", tileType: "directory-tile")), .folder(url: URL(string: "file:///Users/me/Downloads/")!))
        expectEqual(DockTile(preferences: ["tile-type": "spacer-tile", "tile-data": ["file-label": ""]]), .spacer)
        expectEqual(DockTile(preferences: ["tile-type": "small-spacer-tile"]), .smallSpacer)
        expectEqual(DockTile(preferences: ["tile-type": "url-tile"]), .other(type: "url-tile"))
        expectEqual(DockTile(preferences: fileTile("https://example.com")), .other(type: "file-tile"))
    },
    TestCase(name: "new tiles read back as what they were made from") {
        let tiles: [DockTile] = [
            .app(url: URL(fileURLWithPath: "/Applications/Foo.app"), bundleID: "com.example.foo"),
            .app(url: URL(fileURLWithPath: "/Applications/Bar.app"), bundleID: nil),
            .folder(url: URL(fileURLWithPath: "/Users/me/Documents", isDirectory: true)),
            .spacer,
            .smallSpacer,
        ]
        for tile in tiles {
            expectEqual(DockTile(preferences: tile.preferences), tile)
        }
        let data = DockTile.app(url: URL(fileURLWithPath: "/Applications/Foo.app"), bundleID: nil).preferences["tile-data"] as? [String: Any]
        expectEqual(data?["file-label"] as? String, "Foo")
    },
]
