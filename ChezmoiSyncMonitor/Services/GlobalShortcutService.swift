import Carbon.HIToolbox
import os

/// A service that registers and unregisters a global hotkey using the Carbon Event API.
///
/// When the registered hotkey is pressed from anywhere in the system, the provided
/// action closure is called on the main actor. Only one hotkey can be registered at a time;
/// calling `register` again will first unregister any existing hotkey.
@MainActor
final class GlobalShortcutService {

    /// Logger for hotkey registration events.
    private static let logger = Logger(
        subsystem: "cc.carpio.ChezmoiSyncMonitor",
        category: "GlobalShortcut"
    )

    /// Reference to the registered Carbon hotkey, or `nil` if none is active.
    private var hotKeyRef: EventHotKeyRef?

    /// Reference to the installed Carbon event handler, or `nil` if not installed.
    private var eventHandler: EventHandlerRef?

    /// The closure to execute when the hotkey fires.
    private let action: @MainActor () -> Void

    /// Creates a new service with the given action closure.
    /// - Parameter action: The closure to run when the global hotkey is pressed.
    init(action: @MainActor @escaping () -> Void) {
        self.action = action
    } // End of init(action:)

    /// Registers a global hotkey with the given shortcut configuration.
    ///
    /// If a hotkey is already registered, it is unregistered first. Uses the Carbon
    /// `RegisterEventHotKey` API with a stable fourCC signature (`CZSM`) and ID 1.
    ///
    /// - Parameter shortcut: The key code and modifier combination to register.
    /// - Returns: `true` if registration succeeded, `false` if the shortcut is unavailable.
    func register(shortcut: KeyboardShortcutModel) -> Bool {
        // Clean up any existing registration
        unregister()

        // Install the event handler if not yet installed
        if eventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            // Store a raw pointer to self for the C callback
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()

            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                hotKeyCallback,
                1,
                &eventType,
                selfPtr,
                &eventHandler
            )

            if status != noErr {
                Self.logger.error("Failed to install event handler: \(status)")
                return false
            }
        } // End of event handler installation

        // Convert Carbon modifier flags to the format RegisterEventHotKey expects
        var carbonModifiers: UInt32 = 0
        if shortcut.modifiers & UInt32(cmdKey) != 0 { carbonModifiers |= UInt32(cmdKey) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { carbonModifiers |= UInt32(optionKey) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { carbonModifiers |= UInt32(controlKey) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { carbonModifiers |= UInt32(shiftKey) }

        // FourCC signature: 'CZSM'
        let signature: FourCharCode = 0x435A534D

        var hotKeyID = EventHotKeyID(signature: signature, id: 1)

        let regStatus = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            Self.logger.warning("Failed to register hotkey (code=\(shortcut.keyCode), mods=\(shortcut.modifiers)): status \(regStatus)")
            return false
        }

        Self.logger.info("Registered global shortcut: \(shortcut.displayString)")
        return true
    } // End of func register(shortcut:)

    /// Unregisters the current global hotkey and removes the event handler.
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            Self.logger.info("Unregistered global shortcut")
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    } // End of func unregister()

    deinit {
        // Carbon resources should already be cleaned up via unregister() before deallocation.
        // We cannot access @MainActor properties from nonisolated deinit in Swift 6.
    } // End of deinit

    /// Invokes the action closure. Called from the static C callback.
    fileprivate func handleHotKey() {
        action()
    } // End of func handleHotKey()
} // End of class GlobalShortcutService

/// C-compatible callback function for Carbon hotkey events.
///
/// Retrieves the `GlobalShortcutService` instance from the `userData` pointer
/// and calls its `handleHotKey()` method on the main actor.
///
/// - Parameters:
///   - nextHandler: The next handler in the Carbon event chain.
///   - event: The Carbon event that fired.
///   - userData: An opaque pointer to the `GlobalShortcutService` instance.
/// - Returns: `noErr` on success.
private func hotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }

    let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData)
        .takeUnretainedValue()

    Task { @MainActor in
        service.handleHotKey()
    }

    return noErr
} // End of func hotKeyCallback
