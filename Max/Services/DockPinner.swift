import AppKit
import ApplicationServices
import Observation

/// Keeps Apple's Dock on a chosen display. macOS moves the Dock to whichever display's Dock edge the pointer is
/// pushed against, so Max stops the pointer just short of that edge on the other displays. macOS also moves the
/// Dock by itself when displays come and go (a tablet extending the desktop, say); after any display change Max
/// checks where the Dock really is and, if it left, pushes at the pinned display's edge to call it back. Needs
/// Accessibility access (to filter pointer events and read the Dock) and "Displays have separate Spaces"
/// (otherwise the Dock never leaves the primary display).
@Observable
final class DockPinner {
    struct Display: Identifiable, Equatable, Sendable {
        /// The display's CoreGraphics UUID, stable across reconnects.
        var id: String
        var name: String
        /// In AppKit screen coordinates.
        var frame: CGRect
    }

    private(set) var displays: [Display] = []
    /// Whether macOS lets the Dock move between displays at all.
    private(set) var separateSpaces = true
    /// The display the Dock is on now, when it reserves space there.
    private(set) var dockDisplay: Display?
    /// True while the pointer filter is running.
    private(set) var isEnforcing = false

    @ObservationIgnored private let clamp = EdgeClamp()
    @ObservationIgnored private var pinned: String?
    @ObservationIgnored private var orientation: DockOrientation = .bottom
    @ObservationIgnored private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    @ObservationIgnored private var retryTimer: Timer?
    @ObservationIgnored private var recallTimer: Timer?
    @ObservationIgnored private var recallChecksLeft = 0
    @ObservationIgnored private var recallPushesLeft = 0
    @ObservationIgnored private var isPushing = false

    init() {
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.dock.prefchanged"))
        refresh()
    }

    func update(pinnedDisplay: String?, orientation: DockOrientation) {
        guard pinnedDisplay != pinned || orientation != self.orientation else { return }
        pinned = pinnedDisplay
        self.orientation = orientation
        apply()
        scheduleRecall()
    }

    func refresh() {
        let screens = NSScreen.screens
        let updated = screens.compactMap(Self.display(for:))
        if updated != displays { displays = updated }
        let spans = CFPreferencesCopyAppValue("spans-displays" as CFString, "com.apple.spaces" as CFString) as? Bool ?? false
        if separateSpaces == spans { separateSpaces = !spans }
        let geometry = screens.map { (frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let current = DockGeometry.dockScreenIndex(in: geometry, orientation: orientation).flatMap { Self.display(for: screens[$0]) }
        if current != dockDisplay { dockDisplay = current }
        apply()
        scheduleRecall()
    }

    private func apply() {
        guard let pinned, separateSpaces, displays.count > 1,
              let index = displays.firstIndex(where: { $0.id == pinned }),
              let primaryHeight = NSScreen.screens.first?.frame.height else {
            stopEnforcing()
            return
        }
        let frames = cgFrames(primaryHeight: primaryHeight)
        clamp.configure(edges: DockPinning.blockedEdges(displays: frames, pinned: index, orientation: orientation), orientation: orientation)
        let started = AXIsProcessTrusted() && clamp.start()
        if started != isEnforcing { isEnforcing = started }
        // Without Accessibility access the filter cannot start; try again once it is granted.
        if started {
            retryTimer?.invalidate()
            retryTimer = nil
        } else if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            }
        }
    }

    /// The displays in CoreGraphics coordinates, as event taps and Accessibility use them: measured from the primary
    /// display's top edge, y downward.
    private func cgFrames(primaryHeight: CGFloat) -> [CGRect] {
        displays.map { CGRect(x: $0.frame.minX, y: primaryHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
    }

    // MARK: Calling the Dock back

    /// Watch for the Dock having left the pinned display. Display changes settle over a few seconds (and macOS may
    /// move the Dock partway through), so this checks every half second for half a minute, pushing at most 3 times.
    private func scheduleRecall() {
        recallChecksLeft = 60
        recallPushesLeft = 3
        guard recallTimer == nil else { return }
        recallTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.recallTick() }
        }
    }

    private func stopRecall() {
        recallTimer?.invalidate()
        recallTimer = nil
    }

    private func recallTick() {
        recallChecksLeft -= 1
        if recallChecksLeft <= 0 || recallPushesLeft <= 0 { stopRecall() }
        guard !isPushing, let pinned, separateSpaces, displays.count > 1, AXIsProcessTrusted(),
              let pinnedIndex = displays.firstIndex(where: { $0.id == pinned }),
              let primaryHeight = NSScreen.screens.first?.frame.height,
              let list = Self.dockListFrame() else { return }
        let frames = cgFrames(primaryHeight: primaryHeight)
        guard let at = DockPinning.displayIndex(ofDockList: list, displays: frames, orientation: orientation) else { return }
        if at == pinnedIndex {
            stopRecall()
            return
        }
        // Wait until the pointer has been still for a moment, so the push never fights a hand on the mouse.
        guard CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved) >= 1,
              let point = DockPinning.recallPoint(displays: frames, pinned: pinnedIndex, orientation: orientation) else { return }
        recallPushesLeft -= 1
        push(at: point)
    }

    /// What a hand does to move the Dock: rest the pointer on the edge and keep pushing past it, then put the pointer
    /// back where it was. The point is on the pinned display, outside every blocked strip, so the clamp lets it through.
    private func push(at point: CGPoint) {
        isPushing = true
        let back = CGEvent(source: nil)?.location ?? point
        let (inward, deltaX, deltaY): (CGPoint, Int64, Int64) = switch orientation {
        case .bottom: (CGPoint(x: point.x, y: point.y - 6), 0, 8)
        case .left: (CGPoint(x: point.x + 6, y: point.y), -8, 0)
        case .right: (CGPoint(x: point.x - 6, y: point.y), 8, 0)
        }
        CGWarpMouseCursorPosition(inward)
        Task { [weak self] in
            for _ in 0..<16 {
                try? await Task.sleep(for: .milliseconds(50))
                if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
                    event.setIntegerValueField(.mouseEventDeltaX, value: deltaX)
                    event.setIntegerValueField(.mouseEventDeltaY, value: deltaY)
                    event.post(tap: .cghidEventTap)
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
            CGWarpMouseCursorPosition(back)
            self?.isPushing = false
        }
    }

    /// The frame of the Dock's list of items, in CoreGraphics coordinates. Unlike the strip macOS reserves (which can
    /// stay on a display after the Dock has left it), this is where the Dock actually is.
    private static func dockListFrame() -> CGRect? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success else { return nil }
        for element in children as? [AXUIElement] ?? [] {
            var role: AnyObject?
            var position: AnyObject?
            var size: AnyObject?
            guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
                  role as? String == kAXListRole,
                  AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
                  AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
                  let position, let size,
                  CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { continue }
            var origin = CGPoint.zero
            var extent = CGSize.zero
            guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
                  AXValueGetValue(size as! AXValue, .cgSize, &extent), extent.width > 0 else { continue }
            return CGRect(origin: origin, size: extent)
        }
        return nil
    }

    private func stopEnforcing() {
        clamp.stop()
        retryTimer?.invalidate()
        retryTimer = nil
        if isEnforcing { isEnforcing = false }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observers.append((center, token))
    }

    private static func display(for screen: NSScreen) -> Display? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
              let id = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        return Display(id: id, name: screen.localizedName, frame: screen.frame)
    }
}

/// The pointer filter: an event tap that moves pointer events out of the blocked edge strips before anything else
/// sees them. Runs on the main run loop, but the tap's C callback is not actor-isolated, so its state sits behind a lock.
nonisolated private final class EdgeClamp: @unchecked Sendable {
    private let lock = NSLock()
    private var edges: [CGRect] = []
    private var orientation: DockOrientation = .bottom
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func configure(edges: [CGRect], orientation: DockOrientation) {
        lock.withLock {
            self.edges = edges
            self.orientation = orientation
        }
    }

    func start() -> Bool {
        if lock.withLock({ tap != nil }) { return true }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: edgeClampCallback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lock.withLock {
            self.tap = tap
            self.source = source
        }
        return true
    }

    func stop() {
        let (tap, source) = lock.withLock { () -> (CFMachPort?, CFRunLoopSource?) in
            defer {
                self.tap = nil
                self.source = nil
            }
            return (self.tap, self.source)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS switches off a tap that answers too slowly; turn it back on.
            if let tap = lock.withLock({ tap }) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let (edges, orientation) = lock.withLock { (edges, orientation) }
        guard let point = DockPinning.clamped(event.location, edges: edges, orientation: orientation) else { return }
        event.location = point
        // Changing the event alone may not move the pointer itself, so move it too.
        CGWarpMouseCursorPosition(point)
        // Drop the push toward the edge too, so the Dock never sees one.
        switch orientation {
        case .bottom: event.setIntegerValueField(.mouseEventDeltaY, value: min(0, event.getIntegerValueField(.mouseEventDeltaY)))
        case .left: event.setIntegerValueField(.mouseEventDeltaX, value: max(0, event.getIntegerValueField(.mouseEventDeltaX)))
        case .right: event.setIntegerValueField(.mouseEventDeltaX, value: min(0, event.getIntegerValueField(.mouseEventDeltaX)))
        }
    }
}

nonisolated private func edgeClampCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<EdgeClamp>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}
