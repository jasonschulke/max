import AppKit
import SwiftUI

extension RGBAColor {
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent, alpha: srgb.alphaComponent)
    }

    init?(_ color: Color) {
        self.init(NSColor(color))
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension OverlayConfiguration.BlurMaterial {
    var material: NSVisualEffectView.Material {
        switch self {
        case .underWindowBackground: .underWindowBackground
        case .windowBackground: .windowBackground
        case .titlebar: .titlebar
        case .menu: .menu
        case .popover: .popover
        case .headerView: .headerView
        case .sheet: .sheet
        case .hudWindow: .hudWindow
        case .sidebar: .sidebar
        case .contentBackground: .contentBackground
        case .fullScreenUI: .fullScreenUI
        case .toolTip: .toolTip
        }
    }
}
