import AppKit
import Observation

/// Owns the overlay window and keeps it in sync with the settings, the Dock, and the displays.
final class OverlayController {
    private let store: SettingsStore
    private let dockObserver: DockObserver
    private let revealTracker = DockRevealTracker()
    private let window = OverlayWindow()
    private let backdrop = OverlayBackdropView(frame: .zero)
    private var observationTask: Task<Void, Never>?
    private var visibilityGeneration = 0
    private var hasApplied = false

    private let changeDuration = 0.25

    init(store: SettingsStore, dockObserver: DockObserver) {
        self.store = store
        self.dockObserver = dockObserver
        window.contentView = backdrop
    }

    private struct Snapshot: Equatable {
        var configuration: OverlayConfiguration
        var isInteracting: Bool
        var dock: DockInfo
        var screenFrame: CGRect
        var visibleFrame: CGRect
        var isRevealed: Bool
    }

    func start() {
        observationTask?.cancel()
        observationTask = Task { [store, dockObserver, revealTracker] in
            // Emits the current snapshot first, then one per change (coalesced per run-loop turn).
            let snapshots = Observations {
                Snapshot(
                    configuration: store.configuration,
                    isInteracting: store.isInteracting,
                    dock: dockObserver.dock,
                    screenFrame: dockObserver.screenFrame,
                    visibleFrame: dockObserver.visibleFrame,
                    isRevealed: revealTracker.isRevealed
                )
            }
            for await snapshot in snapshots {
                guard !Task.isCancelled else { break }
                self.apply(snapshot)
            }
        }
    }

    private func apply(_ snapshot: Snapshot) {
        let config = snapshot.configuration
        let animated = hasApplied && config.animationsEnabled && !snapshot.isInteracting
        defer { hasApplied = true }

        let thickness = DockGeometry.thickness(
            configuration: config, dock: snapshot.dock,
            screenFrame: snapshot.screenFrame, visibleFrame: snapshot.visibleFrame
        )
        let frame = DockGeometry.overlayFrame(
            thickness: thickness, orientation: snapshot.dock.orientation,
            screenFrame: snapshot.screenFrame, visibleFrame: snapshot.visibleFrame
        )
        setFrame(frame, animated: animated)
        backdrop.apply(config, orientation: snapshot.dock.orientation)

        let followsDock = config.isEnabled && snapshot.dock.autoHides && config.mirrorsDockAutoHide
        if followsDock {
            let zone = DockGeometry.revealZone(orientation: snapshot.dock.orientation, screenFrame: snapshot.screenFrame, thickness: thickness)
            revealTracker.start(zone: zone, revealDelay: snapshot.dock.autoHideDelay)
        } else {
            revealTracker.stop()
        }

        let visible: Bool
        if !config.isEnabled {
            visible = false
        } else if snapshot.dock.autoHides {
            visible = config.mirrorsDockAutoHide && snapshot.isRevealed
        } else {
            visible = true
        }
        let duration = snapshot.dock.autoHides ? snapshot.dock.autoHideDuration : changeDuration
        setVisible(visible, opacity: config.opacity, animated: animated, duration: duration)
    }

    private func setFrame(_ frame: CGRect, animated: Bool) {
        guard window.frame != frame else { return }
        if animated, window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = changeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func setVisible(_ visible: Bool, opacity: Double, animated: Bool, duration: Double) {
        visibilityGeneration += 1
        let generation = visibilityGeneration
        let target = CGFloat(opacity)

        if visible {
            if !window.isVisible {
                window.alphaValue = animated ? 0 : target
                window.orderFrontRegardless()
            }
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = duration
                    window.animator().alphaValue = target
                }
            } else {
                window.alphaValue = target
            }
        } else {
            guard window.isVisible else { return }
            if animated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    window.animator().alphaValue = 0
                }, completionHandler: { [weak self] in
                    MainActor.assumeIsolated {
                        // A show that started mid-fade bumps the generation; leave the window alone then.
                        guard let self, self.visibilityGeneration == generation else { return }
                        self.window.orderOut(nil)
                    }
                })
            } else {
                window.orderOut(nil)
            }
        }
    }
}
