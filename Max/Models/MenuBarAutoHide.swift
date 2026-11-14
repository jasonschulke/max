import Foundation

/// When the menu bar hides, as System Settings › Menu Bar offers it. macOS acts on two flags: hiding the menu bar on
/// the desktop (set through SkyLight, backing the global `_HIHideMenuBar`) and showing it in full-screen apps (the
/// global `AppleMenuBarVisibleInFullscreen`). System Settings also records which option its picker shows, as the raw
/// value. Measured on macOS 27.
nonisolated enum MenuBarAutoHide: Int, CaseIterable, Identifiable, Sendable {
    case always = 0
    case onDesktopOnly = 1
    case inFullScreenOnly = 2
    case never = 3

    /// Global default macOS saves "hide on the desktop" in; SkyLight's call applies the flag but doesn't write it.
    static let hidesOnDesktopKey = "_HIHideMenuBar"
    /// Global default; missing means the menu bar hides in full-screen apps.
    static let visibleInFullScreenKey = "AppleMenuBarVisibleInFullscreen"
    /// Where System Settings keeps its picker's choice.
    static let optionDomain = "com.apple.controlcenter"
    static let optionKey = "AutoHideMenuBarOption"
    /// Posted after a change, so apps and System Settings pick it up.
    static let changeNotifications = [
        "AppleInterfaceMenuBarHidingChangedNotification",
        "AppleInterfaceFullScreenMenuBarVisibilityChangedNotification",
    ]

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .always: "Always"
        case .onDesktopOnly: "On Desktop Only"
        case .inFullScreenOnly: "In Full Screen Only"
        case .never: "Never"
        }
    }

    var hidesOnDesktop: Bool { self == .always || self == .onDesktopOnly }
    var visibleInFullScreen: Bool { self == .onDesktopOnly || self == .never }

    init(hidesOnDesktop: Bool, visibleInFullScreen: Bool) {
        switch (hidesOnDesktop, visibleInFullScreen) {
        case (true, false): self = .always
        case (true, true): self = .onDesktopOnly
        case (false, false): self = .inFullScreenOnly
        case (false, true): self = .never
        }
    }
}
