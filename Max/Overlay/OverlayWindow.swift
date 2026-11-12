import AppKit

/// Borderless window on every Space that holds the bar. Behind Apple's Dock it is click-through; drawing its own
/// Dock it sits above Apple's and takes clicks without activating Max, so the app the user is in keeps focus.
final class OverlayWindow: NSPanel {

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        setDrawsDock(false)
    }

    /// One step below Apple's Dock (above app windows, the Dock on top) or, when drawing Max's own Dock, one step above it.
    func setDrawsDock(_ drawsDock: Bool) {
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        let newLevel = NSWindow.Level(rawValue: drawsDock ? dockLevel + 1 : dockLevel - 1)
        if level != newLevel { level = newLevel }
        ignoresMouseEvents = !drawsDock
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
