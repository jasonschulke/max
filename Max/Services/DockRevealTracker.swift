import AppKit
import Observation

/// Mirrors an auto-hiding Dock without needing Accessibility access: watches the pointer and
/// flips `isRevealed` using the Dock's own reveal delay.
@Observable
final class DockRevealTracker {
    private(set) var isRevealed = false

    @ObservationIgnored private var zone: DockGeometry.RevealZone?
    @ObservationIgnored private var revealDelay = DockInfo.defaultAutoHideDelay
    @ObservationIgnored private var globalMonitor: Any?
    @ObservationIgnored private var localMonitor: Any?
    @ObservationIgnored private var revealTimer: Timer?
    @ObservationIgnored private var dismissTimer: Timer?

    /// How long the pointer may leave the strip before the bar follows the Dock out.
    private let dismissDelay = 0.2

    var isTracking: Bool { globalMonitor != nil }

    func start(zone: DockGeometry.RevealZone, revealDelay: Double) {
        self.zone = zone
        self.revealDelay = revealDelay
        if globalMonitor == nil {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated { self?.evaluate() }
                return event
            }
        }
        evaluate()
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        cancelTimers()
        if isRevealed { isRevealed = false }
    }

    private func evaluate() {
        guard let zone else { return }
        let pointer = NSEvent.mouseLocation
        if isRevealed {
            if zone.contains(pointer) {
                dismissTimer?.invalidate()
                dismissTimer = nil
            } else if dismissTimer == nil {
                dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.dismissTimer = nil
                        self?.isRevealed = false
                    }
                }
            }
        } else {
            if zone.triggers(pointer) {
                guard revealTimer == nil else { return }
                revealTimer = Timer.scheduledTimer(withTimeInterval: revealDelay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.revealTimer = nil
                        self?.isRevealed = true
                    }
                }
            } else {
                revealTimer?.invalidate()
                revealTimer = nil
            }
        }
    }

    private func cancelTimers() {
        revealTimer?.invalidate()
        dismissTimer?.invalidate()
        revealTimer = nil
        dismissTimer = nil
    }
}
