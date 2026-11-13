import AppKit
import ApplicationServices
import Observation

/// Reads where Apple's Dock draws its items, through Accessibility, and keeps that current as the Dock changes:
/// apps launching and quitting, items added or moved, Dock settings, displays, badges.
@Observable
final class DockSkinTracker {
    private(set) var items: [SkinItem] = []
    /// Where the Dock's whole list of items sits, in AppKit screen coordinates. Off screen while the Dock is hidden.
    private(set) var dockFrame: CGRect?
    private(set) var isTrusted = AXIsProcessTrusted()
    /// True while something is dragged in the Dock (reordering, dropping files) so the skin can step aside.
    private(set) var isDragging = false

    /// The bar's frame on screen. Drags that start in it, or bring files into it, count as Dock drags.
    @ObservationIgnored var dockRegion: CGRect = .zero

    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var burstTimers: [Timer] = []
    @ObservationIgnored private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    @ObservationIgnored private var mouseMonitor: Any?
    @ObservationIgnored private var dockList: (pid: pid_t, element: AXUIElement)?
    @ObservationIgnored private var dragStart: (inDock: Bool, pasteboardCount: Int, location: CGPoint)?
    @ObservationIgnored private var bundleIDs: [URL: String] = [:]
    @ObservationIgnored private var hasAskedForAccess = false
    /// Apps that have started launching but not finished, by bundle identifier, with when they started.
    @ObservationIgnored private var launching: [String: Date] = [:]

    /// Badges and running state change without notice, so the Dock is also re-read on this interval.
    private let pollInterval = 2.0
    /// Re-reads after a change, catching the Dock's layout animation as it settles.
    private let burstDelays = [0.0, 0.15, 0.4, 0.8, 1.5]
    /// How long the skin stays away after a drag ends, while the Dock lands the dropped item.
    private let dragSettleDelay = 0.35
    /// An app that never reports finishing its launch stops bouncing after this long.
    private let launchTimeout = 20.0

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            observe(workspace, name)
        }
        observeLaunches(workspace)
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.dock.prefchanged"))

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.handleMouse(type) }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        if !hasAskedForAccess, !AXIsProcessTrusted() {
            hasAskedForAccess = true
            requestAccess()
        }
        refresh()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
        burstTimers.forEach { $0.invalidate() }
        burstTimers = []
        dockList = nil
        if !items.isEmpty { items = [] }
        if dockFrame != nil { dockFrame = nil }
        if isDragging { isDragging = false }
    }

    /// Shows the system prompt for Accessibility access. Asked once per launch while skinning lacks it, and from Settings.
    func requestAccess() {
        guard !AXIsProcessTrusted() else {
            isTrusted = true
            return
        }
        // An entry left by an earlier build, whose signature no longer matches, keeps macOS from prompting
        // while granting nothing. Max clears its own entry first; it has no access to lose.
        if let bundleID = Bundle.main.bundleIdentifier {
            let tccutil = Process()
            tccutil.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            tccutil.arguments = ["reset", "Accessibility", bundleID]
            try? tccutil.run()
            tccutil.waitUntilExit()
        }
        isTrusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    // MARK: Reading the Dock

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon() }
        }
        observers.append((center, token))
    }

    private func refreshSoon() {
        burstTimers.forEach { $0.invalidate() }
        burstTimers = burstDelays.map { delay in
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func refresh() {
        guard isRunning else { return }
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        guard trusted, let list = currentDockList() else {
            if !items.isEmpty { items = [] }
            return
        }
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &children) == .success,
              let elements = children as? [AXUIElement] else {
            // The Dock restarted; find it again next time.
            dockList = nil
            return
        }
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let listFrame = Self.frame(of: list, screenHeight: screenHeight)
        if listFrame != dockFrame { dockFrame = listFrame }
        launching = launching.filter { Date().timeIntervalSince($0.value) < launchTimeout }
        let updated = elements.compactMap { item(from: $0, screenHeight: screenHeight, frontmost: frontmost) }
        if updated != items { items = updated }
    }

    // MARK: Launches

    private func observeLaunches(_ center: NotificationCenter) {
        let events: [(Notification.Name, Bool)] = [
            (NSWorkspace.willLaunchApplicationNotification, true),
            (NSWorkspace.didLaunchApplicationNotification, false),
            (NSWorkspace.didTerminateApplicationNotification, false),
        ]
        for (name, started) in events {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.launch(bundleID, started: started) }
            }
            observers.append((center, token))
        }
    }

    private func launch(_ bundleID: String?, started: Bool) {
        guard let bundleID else { return }
        launching[bundleID] = started ? Date() : nil
        let updated = items.map { item -> SkinItem in
            var item = item
            item.isLaunching = item.url.flatMap { self.bundleID(for: $0) }.map { launching[$0] != nil } ?? false
            return item
        }
        if updated != items { items = updated }
    }

    private static let attributes = [
        kAXSubroleAttribute, kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute,
        kAXURLAttribute, "AXIsApplicationRunning", "AXStatusLabel",
    ] as CFArray

    private func item(from element: AXUIElement, screenHeight: CGFloat, frontmost: String?) -> SkinItem? {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, Self.attributes, [], &values) == .success,
              let values = values as? [AnyObject], values.count == 7 else { return nil }
        guard let position = Self.point(values[2]), let size = Self.size(values[3]) else { return nil }
        let frame = DockSkin.appKitFrame(axPosition: position, axSize: size, primaryScreenHeight: screenHeight)
        let url = values[4] as? URL
        var item = SkinItem(
            kind: DockSkin.kind(forSubrole: values[0] as? String),
            title: values[1] as? String ?? "",
            url: url,
            frame: DockSkin.settled(frame),
            isRunning: (values[5] as? NSNumber)?.boolValue ?? false,
            badge: (values[6] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
        if item.kind == .app, let url, let id = bundleID(for: url) {
            item.isActive = id == frontmost
            item.isLaunching = launching[id] != nil
        }
        return item
    }

    private static func frame(of element: AXUIElement, screenHeight: CGFloat) -> CGRect? {
        var position: AnyObject?
        var size: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size, let origin = point(position), let extent = Self.size(size) else { return nil }
        return DockSkin.appKitFrame(axPosition: origin, axSize: extent, primaryScreenHeight: screenHeight)
    }

    /// Missing attributes come back as AXValues of the error type, which these reject.
    private static func point(_ object: AnyObject) -> CGPoint? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(object as! AXValue, .cgPoint, &point) ? point : nil
    }

    private static func size(_ object: AnyObject) -> CGSize? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(object as! AXValue, .cgSize, &size) ? size : nil
    }

    private func bundleID(for url: URL) -> String? {
        if let id = bundleIDs[url] { return id }
        let id = Bundle(url: url)?.bundleIdentifier
        if let id { bundleIDs[url] = id }
        return id
    }

    /// The Dock's list of items. Looked up again whenever the Dock restarts.
    private func currentDockList() -> AXUIElement? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        if let dockList, dockList.pid == dock.processIdentifier { return dockList.element }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success else { return nil }
        let list = (children as? [AXUIElement] ?? []).first { element in
            var role: AnyObject?
            return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success && role as? String == kAXListRole
        }
        dockList = list.map { (dock.processIdentifier, $0) }
        return list
    }

    // MARK: Drags

    private func handleMouse(_ type: NSEvent.EventType) {
        let location = NSEvent.mouseLocation
        switch type {
        case .leftMouseDown:
            dragStart = (dockRegion.contains(location), NSPasteboard(name: .drag).changeCount, location)
        case .leftMouseDragged:
            guard !isDragging, let start = dragStart else { return }
            let reordering = start.inDock && hypot(location.x - start.location.x, location.y - start.location.y) > 4
            // A new drag-pasteboard change means a real drag session (files, apps), not a window being moved.
            let droppingIn = NSPasteboard(name: .drag).changeCount != start.pasteboardCount && dockRegion.contains(location)
            if reordering || droppingIn { isDragging = true }
        case .leftMouseUp:
            dragStart = nil
            guard isDragging else { return }
            Timer.scheduledTimer(withTimeInterval: dragSettleDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isDragging = false
                    self?.refreshSoon()
                }
            }
        default:
            break
        }
    }
}
