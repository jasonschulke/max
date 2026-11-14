import Foundation

let menuBarAutoHideTests: [TestCase] = [
    TestCase(name: "each option sets the two flags macOS acts on") {
        expectEqual(MenuBarAutoHide.always.hidesOnDesktop, true)
        expectEqual(MenuBarAutoHide.always.visibleInFullScreen, false)
        expectEqual(MenuBarAutoHide.onDesktopOnly.hidesOnDesktop, true)
        expectEqual(MenuBarAutoHide.onDesktopOnly.visibleInFullScreen, true)
        expectEqual(MenuBarAutoHide.inFullScreenOnly.hidesOnDesktop, false)
        expectEqual(MenuBarAutoHide.inFullScreenOnly.visibleInFullScreen, false)
        expectEqual(MenuBarAutoHide.never.hidesOnDesktop, false)
        expectEqual(MenuBarAutoHide.never.visibleInFullScreen, true)
    },
    TestCase(name: "raw values are System Settings' AutoHideMenuBarOption, in its picker's order") {
        expectEqual(MenuBarAutoHide.allCases.map(\.rawValue), [0, 1, 2, 3])
        expectEqual(MenuBarAutoHide.allCases.map(\.title), ["Always", "On Desktop Only", "In Full Screen Only", "Never"])
    },
    TestCase(name: "the flags read back as the option that sets them") {
        for option in MenuBarAutoHide.allCases {
            expectEqual(MenuBarAutoHide(hidesOnDesktop: option.hidesOnDesktop, visibleInFullScreen: option.visibleInFullScreen), option)
        }
    },
    TestCase(name: "macOS's default, shown on the desktop and hidden in full screen, is In Full Screen Only") {
        expectEqual(MenuBarAutoHide(hidesOnDesktop: false, visibleInFullScreen: false), .inFullScreenOnly)
    },
]
