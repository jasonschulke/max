import AppKit
import Observation

/// Whether the user has been away from the keyboard and pointer for a while, for dimming the bar.
@Observable
final class IdleWatcher {
    private(set) var isIdle = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var threshold: TimeInterval = 300

    /// Checked often enough that the bar brightens within a second of coming back.
    private let checkInterval = 1.0

    func configure(enabled: Bool, after seconds: TimeInterval) {
        threshold = seconds
        if enabled, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            }
            check()
        } else if !enabled {
            timer?.invalidate()
            timer = nil
            if isIdle { isIdle = false }
        }
    }

    private func check() {
        // Any keyboard, pointer, or scroll input counts.
        guard let anyInput = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput) >= threshold
        if idle != isIdle { isIdle = idle }
    }
}
