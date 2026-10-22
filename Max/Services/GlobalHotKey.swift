import AppKit
import Carbon.HIToolbox

/// One system-wide hot key through Carbon's RegisterEventHotKey, which needs no Accessibility permission.
final class GlobalHotKey {

    struct Shortcut: Sendable {
        var keyCode: UInt32
        var modifiers: UInt32
        var display: String

        static let toggleOverlay = Shortcut(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            display: "⌃⌥⌘M"
        )
    }

    private static let signature: OSType = 0x4D41_5848 // "MAXH"

    private let shortcut: Shortcut
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(shortcut: Shortcut, action: @escaping () -> Void) {
        self.shortcut = shortcut
        self.action = action
    }

    var isRegistered: Bool { hotKeyRef != nil }

    func register() {
        guard hotKeyRef == nil else { return }
        if handlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let context = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), Self.eventHandler, 1, &eventType, context, &handlerRef)
        }
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    /// Carbon delivers hot key events on the main thread.
    private nonisolated static let eventHandler: EventHandlerUPP = { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { hotKey.action() }
        return noErr
    }
}
