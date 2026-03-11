import SwiftUI

/// A picker that lets the user choose from common tools or type a custom command.
///
/// Shows a dropdown with well-known options (filtered to those actually installed),
/// a "Custom..." option for free-text entry, and a "Browse..." option to pick
/// an executable via an open panel. The "(predeterminado)" option clears the selection.
struct ExternalToolPicker: View {

    /// The label displayed to the left of the picker.
    let label: String

    /// Two-way binding to the raw command string (e.g., "code", "/usr/bin/vim").
    @Binding var selection: String

    /// The list of well-known tool options to display.
    let options: [ToolOption]

    /// Whether the custom text field is showing (user chose "Custom...").
    @State private var isCustom = false

    /// The custom command text while editing.
    @State private var customText = ""

    /// Sentinel value used in the Picker for the "Custom..." choice.
    private static let customSentinel = "__custom__"

    /// Sentinel value used in the Picker for the "Browse..." choice.
    private static let browseSentinel = "__browse__"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)

                Spacer()

                if isCustom {
                    HStack(spacing: 4) {
                        TextField(Strings.toolPicker.command, text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                            .onSubmit {
                                selection = customText
                            }
                            .onChange(of: customText) { _, newValue in
                                selection = newValue
                            }

                        Button(Strings.toolPicker.ok) {
                            selection = customText
                            if customText.isEmpty {
                                isCustom = false
                            }
                        }
                        .controlSize(.small)

                        Button {
                            isCustom = false
                            customText = ""
                            selection = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Picker("", selection: pickerBinding) {
                        Text(Strings.toolPicker.defaultOption).tag("")

                        Divider()

                        ForEach(availableOptions) { option in
                            Text(option.displayName).tag(option.command)
                        } // End of ForEach over available options

                        Divider()

                        Text(Strings.toolPicker.custom).tag(Self.customSentinel)
                        Text(Strings.toolPicker.browse).tag(Self.browseSentinel)
                    } // End of Picker
                    .frame(width: 200)
                }
            } // End of HStack

            if !selection.isEmpty && !isCustom {
                if let path = resolvedPath(for: selection) {
                    Text(Strings.toolPicker.path(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Strings.toolPicker.notFoundOnSystem)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } // End of VStack
    } // End of body

    /// Binding that intercepts the "Custom..." and "Browse..." sentinel values.
    private var pickerBinding: Binding<String> {
        Binding(
            get: {
                if isCustom { return Self.customSentinel }
                let knownCommands = options.map(\.command)
                if !selection.isEmpty && !knownCommands.contains(selection) {
                    return Self.customSentinel
                }
                return selection
            },
            set: { newValue in
                if newValue == Self.customSentinel {
                    customText = selection
                    isCustom = true
                } else if newValue == Self.browseSentinel {
                    browseForExecutable()
                } else {
                    isCustom = false
                    selection = newValue
                }
            }
        )
    } // End of pickerBinding

    /// Resolves the path for a selection, handling both command names and absolute paths.
    /// - Parameter value: The command name or absolute path.
    /// - Returns: The resolved path, or `nil` if not found.
    private func resolvedPath(for value: String) -> String? {
        if value.hasPrefix("/") {
            if value.hasSuffix(".app") {
                return FileManager.default.fileExists(atPath: value) ? value : nil
            }
            return FileManager.default.isExecutableFile(atPath: value) ? value : nil
        }
        return PATHResolver.findExecutable(value)
    } // End of func resolvedPath(for:)

    /// Filters options to those whose executables are installed on the system.
    private var availableOptions: [ToolOption] {
        options.filter { PATHResolver.findExecutable($0.command) != nil }
    } // End of availableOptions

    /// Shows an NSOpenPanel for the user to locate an executable.
    private func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.title = Strings.toolPicker.selectTool
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            let chosenPath = url.path
            // Force immediate UI feedback for non-standard/custom editor paths.
            customText = chosenPath
            isCustom = true
            selection = chosenPath
        }
    } // End of func browseForExecutable()

    // MARK: - Tool options

    /// Describes a well-known external tool.
    struct ToolOption: Identifiable {
        let id: String
        /// The command name (e.g., "code").
        let command: String
        /// The user-facing display name (e.g., "Visual Studio Code").
        let displayName: String

        /// Creates a new ToolOption.
        /// - Parameters:
        ///   - command: The command name.
        ///   - displayName: The human-readable name.
        init(command: String, displayName: String) {
            self.id = command
            self.command = command
            self.displayName = displayName
        }
    } // End of struct ToolOption

    /// Common text editors available on macOS.
    static let commonEditors: [ToolOption] = [
        ToolOption(command: "code", displayName: "Visual Studio Code"),
        ToolOption(command: "cursor", displayName: "Cursor"),
        ToolOption(command: "subl", displayName: "Sublime Text"),
        ToolOption(command: "atom", displayName: "Atom"),
        ToolOption(command: "mate", displayName: "TextMate"),
        ToolOption(command: "nano", displayName: "nano"),
        ToolOption(command: "vim", displayName: "Vim"),
        ToolOption(command: "nvim", displayName: "Neovim"),
        ToolOption(command: "emacs", displayName: "Emacs"),
    ]

    /// Common merge tools available on macOS.
    static let commonMergeTools: [ToolOption] = [
        ToolOption(command: "opendiff", displayName: "FileMerge (opendiff)"),
        ToolOption(command: "code", displayName: "VS Code (code --diff)"),
        ToolOption(command: "meld", displayName: "Meld"),
        ToolOption(command: "kdiff3", displayName: "KDiff3"),
        ToolOption(command: "vimdiff", displayName: "vimdiff"),
        ToolOption(command: "nvim", displayName: "Neovim diff"),
    ]
} // End of struct ExternalToolPicker
