import AppKit

/// Draws Apple's Dock items over the bar, exactly where the Dock draws them: icons, running indicators, badges,
/// launch bounces, Calendar's date, and the Trash's state. It never takes clicks; those fall through to the Dock.
final class DockSkinView: NSView {
    /// How the icons are drawn.
    struct Style: Equatable {
        var iconScale = 1.0
        var showsIndicators = true
        var showsBadges = true
        var bounces = true
        var trashIsFull = false
    }

    private var items: [SkinItem] = []
    private var orientation: DockOrientation = .bottom
    private var style = Style()
    /// The bar's part of the view; past it is headroom for bouncing icons.
    private var barRect: NSRect = .zero
    private var icons: [URL: NSImage] = [:]
    private var calendarIcon: (day: Int, image: NSImage)?

    /// Icons hopping because their app is launching: when the hops began, and when the last one lands.
    private var bounces: [URL: (start: Date, end: Date?)] = [:]
    private var bounceTimer: Timer?
    private let hopDuration = 0.65
    /// How high an icon hops, as a fraction of its size.
    private let hopHeight = 0.5

    override init(frame: NSRect) {
        super.init(frame: frame)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func update(items: [SkinItem], orientation: DockOrientation, style: Style, barRect: NSRect) {
        guard items != self.items || orientation != self.orientation || style != self.style || barRect != self.barRect else { return }
        self.items = items
        self.orientation = orientation
        self.style = style
        self.barRect = barRect
        updateBounces()
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

    @objc private func dayChanged() {
        calendarIcon = nil
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let window else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        let now = Date()
        for item in items where item.isDrawn {
            // Items come in screen coordinates; the window may have moved since they were read.
            let slot = convert(window.convertFromScreen(item.frame), from: nil)
            draw(item, in: slot, now: now)
        }
    }

    private func draw(_ item: SkinItem, in slot: NSRect, now: Date) {
        let icon = DockSkin.iconFrame(for: slot, in: barRect, orientation: orientation, scale: style.iconScale)
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
            let lift = hopOffset(for: item, side: icon.width, at: now)
            let hopped = icon.offsetBy(dx: lift.x, dy: lift.y)
            image(for: item)?.draw(in: hopped, from: .zero, operation: .sourceOver, fraction: 1)
            if style.showsBadges, let badge = item.badge {
                drawBadge(badge, on: hopped)
            }
        }
        if style.showsIndicators, item.isRunning {
            drawIndicator(at: DockSkin.indicatorCenter(for: icon, orientation: orientation), active: item.isActive)
        }
    }

    private func image(for item: SkinItem) -> NSImage? {
        if item.kind == .trash {
            return NSImage(named: style.trashIsFull ? NSImage.trashFullName : NSImage.trashEmptyName)
        }
        guard let url = item.url else { return nil }
        if url.lastPathComponent == "Calendar.app" {
            return calendarImage(base: cachedIcon(url))
        }
        return cachedIcon(url)
    }

    private func cachedIcon(_ url: URL) -> NSImage {
        if let icon = icons[url] { return icon }
        // A symlinked app (like /Applications/Safari.app) would get an alias arrow.
        let icon = NSWorkspace.shared.icon(forFile: url.resolvingSymlinksInPath().path)
        icons[url] = icon
        return icon
    }

    /// Calendar's Dock icon shows today's date; its file icon does not. Draws the weekday in the red header and the
    /// day of the month below it, over the static grid.
    private func calendarImage(base: NSImage) -> NSImage {
        let today = Date()
        let dayOfEra = Calendar.current.ordinality(of: .day, in: .era, for: today) ?? 0
        if let calendarIcon, calendarIcon.day == dayOfEra { return calendarIcon.image }
        let day = Calendar.current.component(.day, from: today)
        let weekday = today.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        let image = NSImage(size: NSSize(width: 256, height: 256), flipped: false) { rect in
            base.draw(in: rect)
            // The visible icon is the middle 80.5% of the image; the red header is its top quarter.
            let body = rect.insetBy(dx: rect.width * DockSkin.iconPadding, dy: rect.height * DockSkin.iconPadding)
            let header = body.height * 0.247
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225).addClip()
            NSGradient(starting: NSColor(white: 0.97, alpha: 1), ending: NSColor(white: 0.92, alpha: 1))?
                .draw(in: NSRect(x: body.minX, y: body.minY, width: body.width, height: body.height - header), angle: -90)
            NSGraphicsContext.restoreGraphicsState()

            let headerText = NSAttributedString(string: weekday, attributes: [
                .font: NSFont.systemFont(ofSize: header * 0.5, weight: .semibold), .foregroundColor: NSColor.white,
            ])
            let headerSize = headerText.size()
            headerText.draw(at: NSPoint(x: body.midX - headerSize.width / 2, y: body.maxY - header / 2 - headerSize.height / 2))

            let number = NSAttributedString(string: "\(day)", attributes: [
                .font: NSFont.systemFont(ofSize: body.height * 0.52, weight: .regular), .foregroundColor: NSColor(white: 0.12, alpha: 1),
            ])
            let numberSize = number.size()
            let area = body.height - header
            number.draw(at: NSPoint(x: body.midX - numberSize.width / 2, y: body.minY + area / 2 - numberSize.height / 2))
            return true
        }
        calendarIcon = (dayOfEra, image)
        return image
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

    // MARK: Bouncing

    /// Starts hops for apps that began launching; lets the current hop finish for ones that are done.
    private func updateBounces() {
        let now = Date()
        let launching = Set(items.filter { style.bounces && $0.isLaunching }.compactMap(\.url))
        for url in launching where bounces[url]?.end != nil || bounces[url] == nil {
            bounces[url] = (bounces[url]?.start ?? now, nil)
        }
        for (url, bounce) in bounces where !launching.contains(url) && bounce.end == nil {
            let hops = max(1, (now.timeIntervalSince(bounce.start) / hopDuration).rounded(.up))
            bounces[url] = (bounce.start, bounce.start.addingTimeInterval(hops * hopDuration))
        }
        if bounces.isEmpty {
            bounceTimer?.invalidate()
            bounceTimer = nil
        } else if bounceTimer == nil {
            bounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
    }

    private func tick() {
        let now = Date()
        bounces = bounces.filter { $0.value.end.map { now < $0 } ?? true }
        if bounces.isEmpty {
            bounceTimer?.invalidate()
            bounceTimer = nil
        }
        needsDisplay = true
    }

    /// How far a launching app's icon is lifted right now, away from the screen edge.
    private func hopOffset(for item: SkinItem, side: CGFloat, at now: Date) -> CGPoint {
        guard let url = item.url, let bounce = bounces[url] else { return .zero }
        let phase = now.timeIntervalSince(bounce.start).truncatingRemainder(dividingBy: hopDuration) / hopDuration
        let lift = CGFloat(sin(phase * .pi)) * CGFloat(hopHeight) * side
        switch orientation {
        case .bottom: return CGPoint(x: 0, y: lift)
        case .left: return CGPoint(x: lift, y: 0)
        case .right: return CGPoint(x: -lift, y: 0)
        }
    }
}
