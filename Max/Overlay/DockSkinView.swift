import AppKit

/// Draws Apple's Dock items over the bar, exactly where the Dock draws them: icons, running indicators, badges.
/// It never takes clicks; those fall through to the Dock underneath.
final class DockSkinView: NSView {
    private var items: [SkinItem] = []
    private var orientation: DockOrientation = .bottom
    private var icons: [URL: NSImage] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func update(items: [SkinItem], orientation: DockOrientation) {
        guard items != self.items || orientation != self.orientation else { return }
        self.items = items
        self.orientation = orientation
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let window else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        for item in items where item.isDrawn {
            // Items come in screen coordinates; the window may have moved since they were read.
            let slot = convert(window.convertFromScreen(item.frame), from: nil)
            guard slot.intersects(dirtyRect) else { continue }
            draw(item, in: slot)
        }
    }

    private func draw(_ item: SkinItem, in slot: NSRect) {
        let icon = DockSkin.iconFrame(for: slot, in: bounds, orientation: orientation)
        switch item.kind {
        case .separator:
            let length = (orientation == .bottom ? slot.height : slot.width) * 0.6
            let line = orientation == .bottom
                ? NSRect(x: slot.midX - 0.5, y: icon.midY - length / 2, width: 1, height: length)
                : NSRect(x: icon.midX - length / 2, y: slot.midY - 0.5, width: length, height: 1)
            NSColor.separatorColor.setFill()
            line.fill()
            return
        case .minimizedWindow:
            // The Dock shows a live thumbnail Max cannot read; a window symbol stands in.
            let symbol = NSImage(systemSymbolName: "macwindow", accessibilityDescription: item.title)?
                .withSymbolConfiguration(.init(pointSize: icon.height * 0.6, weight: .regular))
            NSColor.labelColor.set()
            symbol?.draw(in: icon.insetBy(dx: icon.width * 0.15, dy: icon.height * 0.15))
        default:
            image(for: item)?.draw(in: icon, from: .zero, operation: .sourceOver, fraction: 1)
        }
        if item.isRunning {
            drawIndicator(at: DockSkin.indicatorCenter(for: icon, orientation: orientation), active: item.isActive)
        }
        if let badge = item.badge {
            drawBadge(badge, on: icon)
        }
    }

    private func image(for item: SkinItem) -> NSImage? {
        if item.kind == .trash {
            return NSImage(named: NSImage.trashEmptyName)
        }
        guard let url = item.url else { return nil }
        if let icon = icons[url] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[url] = icon
        return icon
    }

    /// A dot under running apps, stretched into a short bar under the frontmost one.
    private func drawIndicator(at center: NSPoint, active: Bool) {
        let dot: CGFloat = 4
        let long: CGFloat = active ? 12 : dot
        let size = orientation == .bottom ? NSSize(width: long, height: dot) : NSSize(width: dot, height: long)
        let rect = NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        NSColor.labelColor.withAlphaComponent(active ? 0.85 : 0.6).setFill()
        NSBezierPath(roundedRect: rect, xRadius: dot / 2, yRadius: dot / 2).fill()
    }

    /// A red capsule over the icon's top-right corner, like the Dock's.
    private func drawBadge(_ text: String, on icon: NSRect) {
        let height = max(14, icon.height * 0.42)
        let font = NSFont.systemFont(ofSize: height * 0.62, weight: .semibold)
        let label = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let textSize = label.size()
        let width = max(height, textSize.width + height * 0.5)
        // The icon image has transparent padding; the visible icon's corner is about 10% in.
        let corner = NSPoint(x: icon.maxX - icon.width * 0.1, y: icon.maxY - icon.height * 0.1)
        let badge = NSRect(x: corner.x - width * 0.6, y: corner.y - height * 0.6, width: width, height: height)
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badge, xRadius: height / 2, yRadius: height / 2).fill()
        label.draw(at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2))
    }
}
