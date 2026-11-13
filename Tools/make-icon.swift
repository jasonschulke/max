// Draws Max's app icon and writes it as an .icns file and into the asset catalog.
//   swift Tools/make-icon.swift            (run from the repository root)
// The icon: a dark desktop with two windows tiled flush, square-cornered, above a bar that runs the full width,
// its app tiles in the desktop's violets.
import AppKit

let resources = URL(fileURLWithPath: "Max/Resources")
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Max.iconset")
let catalog = resources.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws the icon on a 1024-point canvas; the caller scales the context.
func drawIcon() {
    // macOS icon grid: an 824-point body centered on the canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 22
    shadow.set()
    color(0x2A2350).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()

    // A dark desktop: deep violet to plum.
    NSGradient(colors: [color(0x2A2350), color(0x1A1530), color(0x2B1838)])!.draw(in: body, angle: -60)

    // Two windows tiled side by side, square corners, flush against each other.
    let barTop: CGFloat = 268
    let windows = [
        (NSRect(x: 188, y: barTop + 64, width: 330, height: 470), color(0x3A3550), color(0xFFFFFF, 0.06)),
        (NSRect(x: 518, y: barTop + 64, width: 318, height: 470), color(0x2F2B45), color(0xFFFFFF, 0.05)),
    ]
    for (frame, fill, title) in windows {
        fill.setFill()
        frame.fill()
        title.setFill()
        NSRect(x: frame.minX, y: frame.maxY - 58, width: frame.width, height: 58).fill()
    }
    for (index, dot) in [color(0xFF5F57), color(0xFEBC2E), color(0x28C840)].enumerated() {
        dot.setFill()
        NSBezierPath(ovalIn: NSRect(x: 214 + CGFloat(index) * 34, y: barTop + 64 + 470 - 41, width: 22, height: 22)).fill()
    }
    drawWebpage(in: windows[0].0)
    drawAppOutline(in: windows[1].0)

    // The bar, edge to edge along the bottom.
    let bar = NSRect(x: body.minX, y: body.minY, width: body.width, height: barTop - body.minY)
    color(0x0C0B14, 0.95).setFill()
    bar.fill()
    NSColor.white.withAlphaComponent(0.2).setFill()
    NSRect(x: bar.minX, y: bar.maxY - 3, width: bar.width, height: 3).fill()

    // App tiles in the desktop's violets, light to dark, with running dots under two of them.
    let tileColors = [color(0xDDD6FE), color(0xC4B5FD), color(0xA78BFA), color(0x8B7CF6), color(0x6D5BD0)]
    let tile: CGFloat = 86
    let gap: CGFloat = 24
    let total = CGFloat(tileColors.count) * tile + CGFloat(tileColors.count - 1) * gap
    var x = body.midX - total / 2
    let tileY = bar.minY + (bar.height - tile) / 2 + 6
    for (index, fill) in tileColors.enumerated() {
        fill.setFill()
        let tileRect = NSRect(x: x, y: tileY, width: tile, height: tile)
        NSBezierPath(roundedRect: tileRect, xRadius: 22, yRadius: 22).fill()
        // A faint glyph on each: dark on the light tiles, light on the dark ones.
        drawGlyph(index, in: tileRect, ink: index < 3 ? color(0x4C3FA0, 0.42) : NSColor.white.withAlphaComponent(0.45))
        if index == 0 || index == 3 {
            color(0xC4B5FD).setFill()
            NSBezierPath(ovalIn: NSRect(x: x + tile / 2 - 6, y: tileY - 24, width: 12, height: 12)).fill()
        }
        x += tile + gap
    }
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: Sketches

/// Faint white, the way content shows through a dark window.
func sketch(_ alpha: CGFloat) -> NSColor { NSColor.white.withAlphaComponent(alpha) }

func fill(_ rect: NSRect, _ alpha: CGFloat, radius: CGFloat = 0) {
    sketch(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func outline(_ rect: NSRect, _ alpha: CGFloat, radius: CGFloat) {
    sketch(alpha).setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: radius, yRadius: radius)
    path.lineWidth = 3
    path.stroke()
}

/// A webpage in the left window: address bar, navigation, a hero, text, and a row of cards.
func drawWebpage(in window: NSRect) {
    let top = window.maxY - 58
    outline(NSRect(x: window.minX + 130, y: top + 16, width: window.width - 150, height: 26), 0.14, radius: 13)
    let left = window.minX + 20
    let width = window.width - 40
    fill(NSRect(x: left, y: top - 44, width: 26, height: 26), 0.14, radius: 6)
    for i in 0..<3 {
        fill(NSRect(x: left + width - 3 * 46 + CGFloat(i) * 46 + 8, y: top - 36, width: 36, height: 10), 0.12, radius: 5)
    }
    let hero = NSRect(x: left, y: top - 190, width: width, height: 126)
    outline(hero, 0.14, radius: 12)
    fill(NSRect(x: hero.minX + 20, y: hero.maxY - 40, width: 170, height: 16), 0.15, radius: 8)
    fill(NSRect(x: hero.minX + 20, y: hero.maxY - 66, width: 120, height: 10), 0.1, radius: 5)
    fill(NSRect(x: hero.minX + 20, y: hero.minY + 18, width: 74, height: 24), 0.16, radius: 12)
    for (i, fraction) in [1.0, 0.86, 0.93].enumerated() {
        fill(NSRect(x: left, y: hero.minY - 30 - CGFloat(i) * 22, width: width * fraction, height: 10), 0.1, radius: 5)
    }
    let cardWidth = (width - 2 * 12) / 3
    for i in 0..<3 {
        let card = NSRect(x: left + CGFloat(i) * (cardWidth + 12), y: window.minY + 22, width: cardWidth, height: 96)
        outline(card, 0.13, radius: 10)
        fill(NSRect(x: card.minX + 12, y: card.maxY - 30, width: card.width - 24, height: 12), 0.12, radius: 6)
    }
}

/// An app in the right window: a sidebar of items beside a list.
func drawAppOutline(in window: NSRect) {
    let top = window.maxY - 58
    outline(NSRect(x: window.midX - 30, y: top + 16, width: 104, height: 26), 0.12, radius: 13)
    let sidebar = NSRect(x: window.minX, y: window.minY, width: 88, height: top - window.minY)
    fill(sidebar, 0.04)
    for i in 0..<5 {
        let y = top - 46 - CGFloat(i) * 34
        fill(NSRect(x: sidebar.minX + 14, y: y, width: 14, height: 14), 0.14, radius: 7)
        fill(NSRect(x: sidebar.minX + 36, y: y + 2, width: 38, height: 10), 0.11, radius: 5)
    }
    let left = sidebar.maxX + 18
    let width = window.maxX - left - 18
    fill(NSRect(x: left, y: top - 44, width: 130, height: 16), 0.15, radius: 8)
    for i in 0..<5 {
        let row = NSRect(x: left, y: top - 120 - CGFloat(i) * 62, width: width, height: 50)
        outline(row, 0.12, radius: 10)
        fill(NSRect(x: row.minX + 12, y: row.minY + 13, width: 24, height: 24), 0.13, radius: 12)
        fill(NSRect(x: row.minX + 48, y: row.minY + 26, width: width * 0.55, height: 9), 0.13, radius: 4.5)
        fill(NSRect(x: row.minX + 48, y: row.minY + 13, width: width * 0.35, height: 7), 0.08, radius: 3.5)
    }
}

/// Line glyphs for the app tiles: mail, tasks, calendar, messages, music.
func drawGlyph(_ index: Int, in tile: NSRect, ink: NSColor) {
    let box = tile.insetBy(dx: 21, dy: 21)
    let path = NSBezierPath()
    path.lineWidth = 6
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    switch index {
    case 0:
        // Mail: an envelope.
        let envelope = NSRect(x: box.minX, y: box.minY + 6, width: box.width, height: box.height - 12)
        path.append(NSBezierPath(roundedRect: envelope, xRadius: 5, yRadius: 5))
        path.move(to: NSPoint(x: envelope.minX + 2, y: envelope.maxY - 2))
        path.line(to: NSPoint(x: envelope.midX, y: envelope.midY - 2))
        path.line(to: NSPoint(x: envelope.maxX - 2, y: envelope.maxY - 2))
    case 1:
        // Tasks: a checked circle.
        path.appendOval(in: box)
        path.move(to: NSPoint(x: box.minX + 11, y: box.midY))
        path.line(to: NSPoint(x: box.midX - 3, y: box.minY + 13))
        path.line(to: NSPoint(x: box.maxX - 10, y: box.maxY - 12))
    case 2:
        // Calendar: a page with a header and two rows of days.
        path.append(NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6))
        path.move(to: NSPoint(x: box.minX, y: box.maxY - 12))
        path.line(to: NSPoint(x: box.maxX, y: box.maxY - 12))
        ink.setFill()
        for row in 0..<2 {
            for column in 0..<3 {
                NSBezierPath(ovalIn: NSRect(x: box.minX + 8 + CGFloat(column) * 10, y: box.minY + 8 + CGFloat(row) * 10, width: 5, height: 5)).fill()
            }
        }
    case 3:
        // Messages: a speech bubble.
        let bubble = NSRect(x: box.minX, y: box.minY + 8, width: box.width, height: box.height - 10)
        path.append(NSBezierPath(roundedRect: bubble, xRadius: 14, yRadius: 14))
        path.move(to: NSPoint(x: bubble.minX + 10, y: bubble.minY + 4))
        path.line(to: NSPoint(x: bubble.minX + 4, y: box.minY - 2))
        path.line(to: NSPoint(x: bubble.minX + 18, y: bubble.minY + 2))
    default:
        // Music: a note.
        path.appendOval(in: NSRect(x: box.minX + 4, y: box.minY, width: 16, height: 13))
        path.move(to: NSPoint(x: box.minX + 19, y: box.minY + 7))
        path.line(to: NSPoint(x: box.minX + 19, y: box.maxY))
        path.line(to: NSPoint(x: box.maxX - 4, y: box.maxY - 8))
    }
    ink.setStroke()
    path.stroke()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

var catalogImages: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let data = png(pixels: points * scale)
        try data.write(to: iconset.appendingPathComponent(name))
        try data.write(to: catalog.appendingPathComponent(name))
        catalogImages.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}

let contents: [String: Any] = ["images": catalogImages, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: catalog.appendingPathComponent("Contents.json"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("Max.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Max/Resources/Max.icns and the AppIcon asset catalog" : "iconutil failed")
