import Cocoa

let app = NSApplication.shared

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
