import AppKit

/// Borderless, click-through window on every Space that holds the bar. Clicks always reach the Dock beneath.
final class OverlayWindow: NSWindow {

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        setCoversDock(false)
    }

    /// One step below the Dock (above app windows, the Dock drawing on top) or, skinning it, one step above it.
    func setCoversDock(_ coversDock: Bool) {
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        let newLevel = NSWindow.Level(rawValue: coversDock ? dockLevel + 1 : dockLevel - 1)
        if level != newLevel { level = newLevel }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
