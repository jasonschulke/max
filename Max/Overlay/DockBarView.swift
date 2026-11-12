import AppKit

/// Max's own Dock: draws the tiles along the bar and handles clicks, menus, reordering, and file drops.
final class DockBarView: NSView {
    private let items: DockItemsStore
    private var tiles: [DockTile] = []
    private var orientation: DockOrientation = .bottom
    private var preferredIconSize = DockInfo.defaultTileSize
    private var icons: [URL: NSImage] = [:]
    private let hoverLabel = HoverLabel()

    private var pressedIndex: Int?
    private var pressLocation: NSPoint = .zero
    private var drag: Drag?
    private var dropTarget: Int?

    /// A kept tile being dragged to a new place in its section.
    private struct Drag {
        var tileIndex: Int
        var source: DockTile.Source
        var location: NSPoint
        var destination: Int
    }

    /// How far the pointer moves before a press becomes a drag.
    private let dragThreshold: CGFloat = 4

    init(items: DockItemsStore) {
        self.items = items
        super.init(frame: .zero)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func update(tiles: [DockTile], orientation: DockOrientation, preferredIconSize: Double) {
        guard tiles != self.tiles || orientation != self.orientation || preferredIconSize != self.preferredIconSize else { return }
        // A press or drag that started on a tile that moved or vanished no longer means anything.
        if let pressedIndex, !Self.sameTile(self.tiles, tiles, at: pressedIndex) {
            self.pressedIndex = nil
            drag = nil
        }
        self.tiles = tiles
        self.orientation = orientation
        self.preferredIconSize = preferredIconSize
        needsDisplay = true
    }

    private static func sameTile(_ old: [DockTile], _ new: [DockTile], at index: Int) -> Bool {
        old.indices.contains(index) && new.indices.contains(index)
            && old[index].kind == new[index].kind && old[index].url == new[index].url && old[index].source == new[index].source
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    // MARK: Layout

    private func layout(order: [Int]) -> DockLayout {
        DockLayout(kinds: order.map { tiles[$0].kind }, bounds: bounds, orientation: orientation, preferredIconSize: preferredIconSize)
    }

    private var restingLayout: DockLayout { layout(order: Array(tiles.indices)) }

    /// Tile indices in drawing order: as stored, except that a dragged tile moves to where it would land.
    private var displayOrder: [Int] {
        var order = Array(tiles.indices)
        guard let drag else { return order }
        let section = sectionIndices(drag.source.section)
        guard let first = section.first else { return order }
        var reordered = section.filter { $0 != drag.tileIndex }
        reordered.insert(drag.tileIndex, at: min(drag.destination, reordered.count))
        order.replaceSubrange(first..<(first + section.count), with: reordered)
        return order
    }

    /// The tile indices of one section of kept items. They are contiguous.
    private func sectionIndices(_ section: DockItems.Section) -> [Int] {
        tiles.indices.filter { tiles[$0].source?.section == section }
    }

    private func tileIndex(at point: NSPoint) -> Int? {
        restingLayout.slot(at: point)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        let order = displayOrder
        let layout = layout(order: order)
        for (slot, index) in order.enumerated() {
            var icon = layout.icons[slot]
            if let drag, drag.tileIndex == index {
                icon.origin = NSPoint(x: drag.location.x - icon.width / 2, y: drag.location.y - icon.height / 2)
            }
            draw(tiles[index], index: index, icon: icon, layout: layout, slot: slot)
        }
    }

    private func draw(_ tile: DockTile, index: Int, icon: NSRect, layout: DockLayout, slot: Int) {
        switch tile.kind {
        case .spacer, .smallSpacer:
            return
        case .separator:
            let length = layout.iconSize * 0.8
            let line = orientation == .bottom
                ? NSRect(x: icon.midX - 0.5, y: icon.midY - length / 2, width: 1, height: length)
                : NSRect(x: icon.midX - length / 2, y: icon.midY - 0.5, width: length, height: 1)
            NSColor.separatorColor.setFill()
            line.fill()
        case .app, .folder, .trash:
            if dropTarget == index {
                NSColor.labelColor.withAlphaComponent(0.15).setFill()
                NSBezierPath(roundedRect: icon.insetBy(dx: -3, dy: -3), xRadius: 8, yRadius: 8).fill()
            }
            let pressed = pressedIndex == index && drag == nil
            image(for: tile).draw(in: icon, from: .zero, operation: .sourceOver, fraction: pressed ? 0.55 : 1)
            if tile.isRunning, drag?.tileIndex != index {
                drawIndicator(at: layout.indicatorCenter(for: slot), active: tile.isActive)
            }
        }
    }

    /// A dot under running apps, stretched into a short bar under the active one.
    private func drawIndicator(at center: NSPoint, active: Bool) {
        let dot: CGFloat = 4
        let long: CGFloat = active ? 12 : dot
        let size = orientation == .bottom ? NSSize(width: long, height: dot) : NSSize(width: dot, height: long)
        let rect = NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        NSColor.labelColor.withAlphaComponent(active ? 0.85 : 0.6).setFill()
        NSBezierPath(roundedRect: rect, xRadius: dot / 2, yRadius: dot / 2).fill()
    }

    private func image(for tile: DockTile) -> NSImage {
        if tile.kind == .trash {
            return NSImage(named: NSImage.trashEmptyName) ?? NSImage()
        }
        guard let url = tile.url else { return NSImage() }
        if let icon = icons[url] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[url] = icon
        return icon
    }

    // MARK: Mouse

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoverLabel(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        hoverLabel.hide()
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            if let menu = menu(for: event) { NSMenu.popUpContextMenu(menu, with: event, for: self) }
            return
        }
        hoverLabel.hide()
        pressLocation = convert(event.locationInWindow, from: nil)
        pressedIndex = tileIndex(at: pressLocation)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressedIndex, let source = tiles[pressedIndex].source else { return }
        let location = convert(event.locationInWindow, from: nil)
        if drag == nil {
            guard hypot(location.x - pressLocation.x, location.y - pressLocation.y) > dragThreshold else { return }
            drag = Drag(tileIndex: pressedIndex, source: source, location: location, destination: source.index)
        }
        drag?.location = location
        let others = sectionIndices(source.section).filter { $0 != pressedIndex }
        drag?.destination = restingLayout.insertionIndex(at: location, among: others)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            pressedIndex = nil
            drag = nil
            needsDisplay = true
        }
        if let drag {
            items.move(in: drag.source.section, from: drag.source.index, to: drag.destination)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        if let pressedIndex, tileIndex(at: location) == pressedIndex {
            items.open(tiles[pressedIndex])
        }
    }

    private func updateHoverLabel(at point: NSPoint) {
        guard pressedIndex == nil, let index = tileIndex(at: point), !tiles[index].title.isEmpty, let window else {
            hoverLabel.hide()
            return
        }
        let icon = window.convertToScreen(convert(restingLayout.icons[index], to: nil))
        hoverLabel.show(tiles[index].title, at: icon, beside: window.frame, orientation: orientation, within: window.screen?.frame ?? window.frame)
    }

    // MARK: Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        hoverLabel.hide()
        guard let index = tileIndex(at: convert(event.locationInWindow, from: nil)) else { return nil }
        let tile = tiles[index]
        let menu = NSMenu()
        switch tile.kind {
        case .app:
            let app = items.runningApplication(for: tile)
            if let app {
                menu.addItem(menuItem(app.isHidden ? "Show" : "Hide") { _ = app.isHidden ? app.unhide() : app.hide() })
            }
            let keep = menuItem("Keep in Dock") { [items] in tile.isKept ? items.remove(tile) : items.keep(tile) }
            keep.state = tile.isKept ? .on : .off
            keep.isEnabled = !tile.isFinder
            menu.addItem(keep)
            menu.addItem(menuItem("Show in Finder") { [items] in items.showInFinder(tile) })
            if let app, !tile.isFinder {
                menu.addItem(.separator())
                menu.addItem(menuItem("Quit") { _ = app.terminate() })
                let forceQuit = menuItem("Force Quit") { _ = app.forceTerminate() }
                forceQuit.isAlternate = true
                forceQuit.keyEquivalentModifierMask = .option
                menu.addItem(forceQuit)
            }
        case .folder:
            menu.addItem(menuItem("Open") { [items] in items.open(tile) })
            menu.addItem(menuItem("Show in Finder") { [items] in items.showInFinder(tile) })
            menu.addItem(.separator())
            menu.addItem(menuItem("Remove from Dock") { [items] in items.remove(tile) })
        case .trash:
            menu.addItem(menuItem("Open") { [items] in items.open(tile) })
        case .spacer, .smallSpacer:
            menu.addItem(menuItem("Remove from Dock") { [items] in items.remove(tile) })
        case .separator:
            return nil
        }
        return menu
    }

    // MARK: Dropping files

    private enum DropAction {
        case trash, openWith(DockTile), keep(index: Int)
    }

    private func fileURLs(_ info: NSDraggingInfo) -> [URL] {
        info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    /// Trash takes anything, an app opens what is dropped on it, and apps dropped between tiles are kept there.
    private func dropAction(_ info: NSDraggingInfo) -> (action: DropAction, target: Int?)? {
        let urls = fileURLs(info)
        guard !urls.isEmpty else { return nil }
        let point = convert(info.draggingLocation, from: nil)
        let index = tileIndex(at: point)
        if let index, tiles[index].kind == .trash { return (.trash, index) }
        if let index, tiles[index].kind == .app, !urls.contains(where: { $0.pathExtension == "app" }) {
            return (.openWith(tiles[index]), index)
        }
        guard urls.allSatisfy({ $0.pathExtension == "app" }) else { return nil }
        let kept = sectionIndices(.apps)
        return (.keep(index: restingLayout.insertionIndex(at: point, among: kept)), nil)
    }

    private func updateDrop(_ info: NSDraggingInfo) -> NSDragOperation {
        let drop = dropAction(info)
        if drop?.target != dropTarget {
            dropTarget = drop?.target
            needsDisplay = true
        }
        switch drop?.action {
        case .trash: return .move
        case .openWith: return .copy
        case .keep: return .link
        case nil: return []
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropTarget = nil
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            dropTarget = nil
            needsDisplay = true
        }
        guard let drop = dropAction(sender) else { return false }
        let urls = fileURLs(sender)
        switch drop.action {
        case .trash: items.moveToTrash(urls)
        case .openWith(let tile): items.open(urls, with: tile)
        case .keep(let index): items.keepApps(at: urls, index: index)
        }
        return true
    }
}

/// Runs a closure when a menu item fires. The item keeps it alive through `representedObject`.
private final class MenuAction: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func run() { handler() }
}

private func menuItem(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
    let action = MenuAction(handler)
    let item = NSMenuItem(title: title, action: #selector(MenuAction.run), keyEquivalent: "")
    item.target = action
    item.representedObject = action
    return item
}

/// The name shown just off the bar beside a hovered tile, like the Dock's labels.
private final class HoverLabel {
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let field = NSTextField(labelWithString: "")
    private let gap: CGFloat = 6

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        let background = NSVisualEffectView()
        background.material = .toolTip
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        background.addSubview(field)
        panel.contentView = background
    }

    func show(_ text: String, at icon: NSRect, beside bar: NSRect, orientation: DockOrientation, within screen: NSRect) {
        field.stringValue = text
        field.sizeToFit()
        let size = NSSize(width: ceil(field.frame.width) + 16, height: ceil(field.frame.height) + 6)
        field.setFrameOrigin(NSPoint(x: 8, y: 3))
        var origin: NSPoint
        switch orientation {
        case .bottom: origin = NSPoint(x: icon.midX - size.width / 2, y: bar.maxY + gap)
        case .left: origin = NSPoint(x: bar.maxX + gap, y: icon.midY - size.height / 2)
        case .right: origin = NSPoint(x: bar.minX - gap - size.width, y: icon.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - size.width - 4)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
