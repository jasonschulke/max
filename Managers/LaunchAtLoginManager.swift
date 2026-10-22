import Cocoa
import ServiceManagement

class LaunchAtLoginManager {

    // MARK: - Public Methods

    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } else {
            // For older macOS versions, throw an error with helpful message
            throw LaunchAtLoginError.unsupportedOS
        }
    }

    static func showErrorAlert(for error: Error, enabled: Bool) {
        let alert = NSAlert()

        if let launchError = error as? LaunchAtLoginError {
            switch launchError {
            case .unsupportedOS:
                alert.messageText = "Launch at Login"
                alert.informativeText = "Launch at login requires macOS 13 or later. Please add this app manually in System Preferences > Users & Groups > Login Items."
                alert.alertStyle = .informational
            }
        } else {
            alert.messageText = "Launch at Login Error"
            alert.informativeText = "Could not \(enabled ? "enable" : "disable") launch at login. Please try again or set it manually in System Settings > General > Login Items.\n\nError: \(error.localizedDescription)"
            alert.alertStyle = .warning
        }

        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showUnsupportedOSAlert() {
        let alert = NSAlert()
        alert.messageText = "Launch at Login"
        alert.informativeText = "Launch at login requires macOS 13 or later. Please add this app manually in System Preferences > Users & Groups > Login Items."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Error Types

enum LaunchAtLoginError: Error {
    case unsupportedOS

    var localizedDescription: String {
        switch self {
        case .unsupportedOS:
            return "This feature requires macOS 13 or later"
        }
    }
}
