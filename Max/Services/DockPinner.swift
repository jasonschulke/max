import AppKit
import ApplicationServices
import Observation

/// Keeps Apple's Dock on a chosen display. macOS moves the Dock to whichever display's Dock edge the pointer is
/// pushed against, so Max stops the pointer just short of that edge on the other displays. Needs Accessibility
/// access (to filter pointer events) and "Displays have separate Spaces" (otherwise the Dock never leaves the
/// primary display).
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
    }

    private func apply() {
        guard let pinned, separateSpaces, displays.count > 1,
              let index = displays.firstIndex(where: { $0.id == pinned }),
              let primaryHeight = NSScreen.screens.first?.frame.height else {
            stopEnforcing()
            return
        }
        // Event taps work in CoreGraphics coordinates: measured from the primary display's top edge, y downward.
        let frames = displays.map { CGRect(x: $0.frame.minX, y: primaryHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
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
