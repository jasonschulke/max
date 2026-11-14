import AppKit
import Observation

/// System Settings › Menu Bar's auto-hide and background settings, changed live through the private SkyLight calls
/// System Settings uses. Looked up at run time, so Dock Max keeps working (without these controls) if a macOS update
/// removes them.
@Observable
final class MenuBarSettings {
    /// When the menu bar hides, or nil when the calls are unavailable.
    private(set) var autoHide: MenuBarAutoHide?
    /// Whether the menu bar draws a background, or nil when the calls are unavailable.
    private(set) var showsBackground: Bool?

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SetAutohide = @convention(c) (Int32, Bool) -> Int32
    private typealias GetAutohide = @convention(c) (Int32, UnsafeMutablePointer<Bool>) -> Int32
    private typealias GetBackground = @convention(c) () -> Bool
    private typealias SetBackground = @convention(c) (Bool, Bool) -> Void

    @ObservationIgnored private let mainConnectionID: MainConnectionID?
    @ObservationIgnored private let setAutohide: SetAutohide?
    @ObservationIgnored private let getAutohide: GetAutohide?
    @ObservationIgnored private let getBackground: GetBackground?
    @ObservationIgnored private let setBackground: SetBackground?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        mainConnectionID = dlsym(skyLight, "CGSMainConnectionID").map { unsafeBitCast($0, to: MainConnectionID.self) }
        setAutohide = dlsym(skyLight, "CGSSetMenuBarAutohideEnabled").map { unsafeBitCast($0, to: SetAutohide.self) }
        getAutohide = dlsym(skyLight, "CGSGetMenuBarAutohideEnabled").map { unsafeBitCast($0, to: GetAutohide.self) }
        getBackground = dlsym(skyLight, "SLSGetMenuBarUseBlurredAppearance").map { unsafeBitCast($0, to: GetBackground.self) }
        setBackground = dlsym(skyLight, "SLSSetMenuBarUseBlurredAppearance").map { unsafeBitCast($0, to: SetBackground.self) }
        refresh()
        // Posted by System Settings too, so changes made there show up here.
        for name in MenuBarAutoHide.changeNotifications {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func refresh() {
        if let mainConnectionID, let getAutohide, setAutohide != nil {
            var hides = false
            if getAutohide(mainConnectionID(), &hides) == 0 {
                CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
                let visible = CFPreferencesCopyAppValue(MenuBarAutoHide.visibleInFullScreenKey as CFString, kCFPreferencesAnyApplication) as? Bool ?? false
                let option = MenuBarAutoHide(hidesOnDesktop: hides, visibleInFullScreen: visible)
                if option != autoHide { autoHide = option }
            }
        }
        if let getBackground, setBackground != nil {
            let shows = getBackground()
            if shows != showsBackground { showsBackground = shows }
        }
    }

    /// Applies an option the way System Settings does, then reads back what macOS has.
    func set(_ option: MenuBarAutoHide) {
        guard let mainConnectionID, let setAutohide else { return }
        _ = setAutohide(mainConnectionID(), option.hidesOnDesktop)
        // The call applies the change live but doesn't save it, so apps and the next login would still read the old one.
        CFPreferencesSetAppValue(MenuBarAutoHide.hidesOnDesktopKey as CFString, NSNumber(value: option.hidesOnDesktop), kCFPreferencesAnyApplication)
        CFPreferencesSetAppValue(MenuBarAutoHide.visibleInFullScreenKey as CFString, NSNumber(value: option.visibleInFullScreen), kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        // Only so System Settings' picker shows the same choice; macOS acts on the two flags.
        CFPreferencesSetAppValue(MenuBarAutoHide.optionKey as CFString, NSNumber(value: option.rawValue), MenuBarAutoHide.optionDomain as CFString)
        CFPreferencesAppSynchronize(MenuBarAutoHide.optionDomain as CFString)
        for name in MenuBarAutoHide.changeNotifications {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(name), object: nil, deliverImmediately: true)
        }
        refresh()
    }

    func setShowsBackground(_ show: Bool) {
        guard let setBackground else { return }
        setBackground(show, true)
        refresh()
    }
}
