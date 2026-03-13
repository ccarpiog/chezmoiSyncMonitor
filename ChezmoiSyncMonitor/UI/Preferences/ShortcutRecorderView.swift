import SwiftUI
import Carbon.HIToolbox
import AppKit

/// A SwiftUI view that lets users record a global keyboard shortcut.
///
/// Displays the current shortcut (or "Not set"), and provides Record / Clear buttons.
/// When recording, it captures the next key combination via an embedded `NSView` that
/// becomes first responder and intercepts `keyDown` events. Bare keys (without at least
/// one modifier) are rejected.
struct ShortcutRecorderView: View {

    /// The currently configured shortcut, or `nil` if none is set.
    @Binding var shortcut: KeyboardShortcutModel?

    /// Callback invoked when the user records, clears, or cancels a shortcut.
    var onShortcutChanged: ((KeyboardShortcutModel?) -> Void)?

    /// Whether the view is actively listening for a key combination.
    @State private var isRecording = false

    /// Whether the last recorded shortcut conflicts with a known system shortcut.
    @State private var showConflictWarning = false

    /// Whether the last registration attempt failed (shortcut taken by another app).
    @State private var showRegistrationError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if isRecording {
                    // Recording state: show the key capture view and cancel button
                    ShortcutCaptureViewRepresentable(
                        isRecording: $isRecording,
                        onCapture: handleCapture
                    )
                    .frame(width: 160, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )

                    Button(Strings.prefs.shortcutStop) {
                        isRecording = false
                    }
                } else {
                    // Display state: show current shortcut and action buttons
                    Text(shortcut?.displayString ?? Strings.prefs.shortcutNotSet)
                        .frame(width: 160, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.1))
                        )

                    Button(Strings.prefs.shortcutRecord) {
                        showConflictWarning = false
                        showRegistrationError = false
                        isRecording = true
                    }

                    if shortcut != nil {
                        Button(Strings.prefs.shortcutClear) {
                            shortcut = nil
                            showConflictWarning = false
                            showRegistrationError = false
                            onShortcutChanged?(nil)
                        }
                    }
                }
            } // End of HStack for shortcut controls

            if showConflictWarning {
                Text(Strings.prefs.shortcutConflictWarning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if showRegistrationError {
                Text(Strings.prefs.shortcutRegistrationFailed)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } // End of VStack
    } // End of computed property body

    /// Handles a captured key combination from the recorder.
    /// - Parameter captured: The shortcut model captured from the key event.
    private func handleCapture(_ captured: KeyboardShortcutModel) {
        isRecording = false
        showRegistrationError = false

        if captured.conflictsWithSystemShortcut {
            showConflictWarning = true
        } else {
            showConflictWarning = false
        }

        shortcut = captured
        onShortcutChanged?(captured)
    } // End of func handleCapture(_:)
} // End of struct ShortcutRecorderView

// MARK: - NSViewRepresentable for key capture

/// Wraps an `NSView` that becomes first responder to capture raw key events.
///
/// When `isRecording` becomes `true`, the view's window makes it the first responder
/// so it can intercept `keyDown`. It requires at least one modifier key (Cmd, Option,
/// or Control) and calls `onCapture` with the resulting `KeyboardShortcutModel`.
private struct ShortcutCaptureViewRepresentable: NSViewRepresentable {

    /// Controls whether the capture view is active.
    @Binding var isRecording: Bool

    /// Called with the captured shortcut when a valid key combo is pressed.
    var onCapture: (KeyboardShortcutModel) -> Void

    /// Creates the underlying `ShortcutCaptureNSView`.
    /// - Parameter context: The representable context.
    /// - Returns: A configured `ShortcutCaptureNSView`.
    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        return view
    } // End of func makeNSView(context:)

    /// Updates the view when SwiftUI state changes.
    /// - Parameters:
    ///   - nsView: The existing `ShortcutCaptureNSView`.
    ///   - context: The representable context.
    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture

        if isRecording {
            // Become first responder after a brief delay to allow window setup
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    } // End of func updateNSView(_:context:)
} // End of struct ShortcutCaptureViewRepresentable

/// An `NSView` subclass that captures `keyDown` events for shortcut recording.
///
/// Accepts the first responder and converts `NSEvent` key codes and modifier flags
/// into Carbon-compatible values for `KeyboardShortcutModel`.
private class ShortcutCaptureNSView: NSView {

    /// Callback invoked when a valid key combination is captured.
    var onCapture: ((KeyboardShortcutModel) -> Void)?

    /// Declares that this view can become the first responder.
    override var acceptsFirstResponder: Bool { true }

    /// Handles key-down events, converting them to a `KeyboardShortcutModel`.
    ///
    /// Rejects key combos without at least one modifier (Cmd, Option, Control).
    /// Shift alone is not considered sufficient.
    /// - Parameter event: The key-down event.
    override func keyDown(with event: NSEvent) {
        let nsModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least Cmd, Option, or Control (shift alone is not enough)
        let hasRequiredModifier = nsModifiers.contains(.command)
            || nsModifiers.contains(.option)
            || nsModifiers.contains(.control)

        guard hasRequiredModifier else {
            NSSound.beep()
            return
        }

        // Reject modifier-only key presses (e.g., pressing Cmd alone)
        let modifierKeyCodes: Set<UInt16> = [
            54, 55, // Right/Left Command
            56, 60, // Left/Right Shift
            58, 61, // Left/Right Option
            59, 62, // Left/Right Control
            63, 57  // Function, Caps Lock
        ]
        guard !modifierKeyCodes.contains(event.keyCode) else { return }

        // Convert NSEvent modifier flags to Carbon modifier flags
        var carbonModifiers: UInt32 = 0
        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let model = KeyboardShortcutModel(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers
        )

        onCapture?(model)
    } // End of func keyDown(with:)

    /// Draws a centered placeholder label when the view is displayed.
    /// - Parameter dirtyRect: The rectangle that needs drawing.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text = Strings.prefs.shortcutRecording
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: point, withAttributes: attributes)
    } // End of func draw(_:)
} // End of class ShortcutCaptureNSView
