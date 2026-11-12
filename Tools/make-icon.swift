// Draws Max's app icon and writes it as an .icns file and into the asset catalog.
//   swift Tools/make-icon.swift            (run from the repository root)
// The icon: a desktop with two windows tiled flush, square-cornered, above a bar that runs the full width.
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
    color(0x3E4FC1).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()

    // The desktop: indigo to violet, with a soft light from the top left.
    NSGradient(colors: [color(0x5A6BF0), color(0x7B55D6), color(0xB65FC2)])!.draw(in: body, angle: -60)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 260, y: 840), radius: 0, toCenter: NSPoint(x: 260, y: 840), radius: 520, options: [])

    // Two windows tiled side by side, square corners, flush against each other.
    let barTop: CGFloat = 268
    let windows = [
        (NSRect(x: 188, y: barTop + 64, width: 330, height: 470), NSColor.white.withAlphaComponent(0.94)),
        (NSRect(x: 518, y: barTop + 64, width: 318, height: 470), color(0xEDEBFA, 0.86)),
    ]
    for (frame, fill) in windows {
        fill.setFill()
        frame.fill()
        // Title bar.
        color(0x1E1B4B, 0.08).setFill()
        NSRect(x: frame.minX, y: frame.maxY - 58, width: frame.width, height: 58).fill()
    }
    for (index, dot) in [color(0xFF5F57), color(0xFEBC2E), color(0x28C840)].enumerated() {
        dot.setFill()
        NSBezierPath(ovalIn: NSRect(x: 214 + CGFloat(index) * 34, y: barTop + 64 + 470 - 41, width: 22, height: 22)).fill()
    }
    // Content lines in each window.
    color(0x1E1B4B, 0.12).setFill()
    for (frame, _) in windows {
        for row in 0..<4 {
            let width = frame.width * [0.72, 0.56, 0.66, 0.42][row]
            NSBezierPath(roundedRect: NSRect(x: frame.minX + 30, y: frame.maxY - 110 - CGFloat(row) * 52, width: width, height: 18), xRadius: 9, yRadius: 9).fill()
        }
    }

    // The bar, edge to edge along the bottom.
    let bar = NSRect(x: body.minX, y: body.minY, width: body.width, height: barTop - body.minY)
    color(0x161A2B, 0.92).setFill()
    bar.fill()
    NSColor.white.withAlphaComponent(0.22).setFill()
    NSRect(x: bar.minX, y: bar.maxY - 3, width: bar.width, height: 3).fill()

    // App tiles, centered, with running dots under two of them.
    let tileColors = [color(0xFF6B5E), color(0xFFB547), color(0x3DD68C), color(0x4CB3FF), color(0xB48CFF)]
    let tile: CGFloat = 86
    let gap: CGFloat = 24
    let total = CGFloat(tileColors.count) * tile + CGFloat(tileColors.count - 1) * gap
    var x = body.midX - total / 2
    let tileY = bar.minY + (bar.height - tile) / 2 + 6
    for (index, fill) in tileColors.enumerated() {
        fill.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: tileY, width: tile, height: tile), xRadius: 22, yRadius: 22).fill()
        if index == 0 || index == 3 {
            NSColor.white.withAlphaComponent(0.8).setFill()
            NSBezierPath(ovalIn: NSRect(x: x + tile / 2 - 6, y: tileY - 26, width: 12, height: 12)).fill()
        }
        x += tile + gap
    }
    NSGraphicsContext.restoreGraphicsState()
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
