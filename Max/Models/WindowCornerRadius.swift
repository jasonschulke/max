import Foundation

/// The corner radius AppKit gives every app's windows, overridable through the undocumented global default
/// `NSConvolutionOverride1` (measured on macOS 27). AppKit ignores zero and negative values, so "square" is stored
/// as a radius too small to see.
nonisolated enum WindowCornerRadius {
    static let defaultsKey = "NSConvolutionOverride1"
    /// What AppKit uses when the default is not set.
    static let systemDefault = 16.0
    static let range = 0.0...systemDefault
    /// Stands in for zero, which AppKit would ignore.
    static let square = 0.01

    /// The value to store for a radius chosen in Settings.
    static func storedValue(forRadius radius: Double) -> Double {
        max(square, radius.clamped(to: range))
    }

    /// The radius a stored value gives windows, or nil when AppKit falls back to its own.
    static func radius(fromStored value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value <= square ? 0 : value
    }
}
