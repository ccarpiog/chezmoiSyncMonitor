import Foundation
import Carbon.HIToolbox

/// A Codable model representing a global keyboard shortcut.
///
/// Stores Carbon virtual key codes and modifier flags so the shortcut can be
/// persisted to disk and re-registered across launches.
struct KeyboardShortcutModel: Codable, Sendable, Equatable {
    /// Carbon virtual key code (e.g., `kVK_ANSI_D` = 2).
    var keyCode: UInt32

    /// Carbon modifier flags (combination of `cmdKey`, `optionKey`, `controlKey`, `shiftKey`).
    var modifiers: UInt32

    /// Returns a human-readable representation like "⌘⇧D".
    var displayString: String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        parts += Self.keyName(for: keyCode)
        return parts
    } // End of computed property displayString

    /// Maps a Carbon virtual key code to its display name.
    /// - Parameter keyCode: The Carbon virtual key code.
    /// - Returns: A short string label for the key (e.g., "D", "F1", "Space").
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        // Letters A-Z
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"

        // Numbers 0-9
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"

        // Special keys
        case kVK_Space: return "Space"
        case kVK_Tab: return "Tab"
        case kVK_Return: return "Return"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"

        // Arrow keys
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"

        // Punctuation / symbols
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"

        default: return "Key\(keyCode)"
        }
    } // End of static func keyName(for:)

    /// Checks whether the shortcut conflicts with well-known macOS system shortcuts.
    /// - Returns: `true` if the shortcut matches a known system or common app shortcut.
    var conflictsWithSystemShortcut: Bool {
        let cmd = UInt32(cmdKey)
        let cmdShift = UInt32(cmdKey) | UInt32(shiftKey)

        // Cmd-only shortcuts
        if modifiers == cmd {
            switch Int(keyCode) {
            case kVK_ANSI_Q, // Quit
                 kVK_ANSI_W, // Close window
                 kVK_ANSI_H, // Hide
                 kVK_ANSI_M, // Minimize
                 kVK_ANSI_A, // Select All
                 kVK_ANSI_C, // Copy
                 kVK_ANSI_V, // Paste
                 kVK_ANSI_X, // Cut
                 kVK_ANSI_Z, // Undo
                 kVK_ANSI_N, // New
                 kVK_ANSI_O, // Open
                 kVK_ANSI_S, // Save
                 kVK_ANSI_P, // Print
                 kVK_ANSI_F, // Find
                 kVK_Tab,    // Cmd-Tab (app switcher)
                 kVK_Space:  // Spotlight
                return true
            default:
                break
            }
        } // End of cmd-only conflict check

        // Cmd+Shift shortcuts
        if modifiers == cmdShift {
            switch Int(keyCode) {
            case kVK_ANSI_Z, // Redo
                 kVK_ANSI_3, // Screenshot
                 kVK_ANSI_4, // Screenshot selection
                 kVK_ANSI_5: // Screenshot options
                return true
            default:
                break
            }
        } // End of cmdShift conflict check

        return false
    } // End of computed property conflictsWithSystemShortcut
} // End of struct KeyboardShortcutModel
