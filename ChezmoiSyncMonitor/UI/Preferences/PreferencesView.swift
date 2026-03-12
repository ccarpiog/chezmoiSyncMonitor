import SwiftUI
import ServiceManagement
import AppKit

/// The main Preferences window with tabbed sections for Sync, Tools, and Advanced settings.
///
/// Changes are saved immediately via `AppStateStore.updatePreferences(_:)`.
struct PreferencesView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// Local copy of preferences for editing. Synced back to appState on every change.
    @State private var prefs: AppPreferences = .defaults

    /// Whether the reset confirmation dialog is showing.
    @State private var showingResetConfirmation = false

    /// The auto-detected chezmoi path, if found.
    @State private var detectedChezmoiPath: String?

    /// The auto-detected git path, if found.
    @State private var detectedGitPath: String?

    /// The auto-detected source repo path, if found.
    @State private var detectedSourceRepoPath: String?

    /// Current registration status for the app login item service.
    @State private var loginItemStatus: SMAppService.Status = .notRegistered

    /// Optional error message from the most recent login-item action.
    @State private var loginItemErrorMessage: String?

    /// Common poll interval values for the Picker.
    private static let pollIntervalValues: [Int] = [1, 2, 5, 10, 15, 30, 60, 0]

    /// Returns the localized label for a poll interval value.
    /// - Parameter value: The interval in minutes, or 0 for manual-only.
    /// - Returns: The localized label string.
    private static func pollIntervalLabel(for value: Int) -> String {
        value == 0 ? Strings.prefs.manualOnly : Strings.prefs.pollMinutes(value)
    } // End of static func pollIntervalLabel(for:)

    var body: some View {
        TabView {
            syncSettingsTab
                .tabItem {
                    Label(Strings.prefs.syncTab, systemImage: "arrow.triangle.2.circlepath")
                }

            toolsTab
                .tabItem {
                    Label(Strings.prefs.toolsTab, systemImage: "wrench")
                }

            advancedTab
                .tabItem {
                    Label(Strings.prefs.advancedTab, systemImage: "gearshape.2")
                }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            prefs = appState.preferences
            detectedChezmoiPath = PATHResolver.chezmoiPath()
            detectedGitPath = PATHResolver.gitPath()
            detectSourceRepoPath()
            refreshLoginItemStatus()
        }
    } // End of computed property body

    // MARK: - Sync Settings Tab

    /// Tab for configuring polling, fetch, batch sync, and notification settings.
    private var syncSettingsTab: some View {
        Form {
            Section(Strings.prefs.polling) {
                Picker(Strings.prefs.pollInterval, selection: Binding(
                    get: { prefs.pollIntervalMinutes },
                    set: { newValue in
                        prefs.pollIntervalMinutes = newValue
                        savePreferences()
                    }
                )) {
                    ForEach(PreferencesView.pollIntervalValues, id: \.self) { value in
                        Text(PreferencesView.pollIntervalLabel(for: value)).tag(value)
                    } // End of ForEach poll interval options
                }
                .pickerStyle(.menu)
            }

            Section(Strings.prefs.behavior) {
                Toggle(Strings.prefs.autoFetch, isOn: Binding(
                    get: { prefs.autoFetchEnabled },
                    set: { newValue in
                        prefs.autoFetchEnabled = newValue
                        savePreferences()
                    }
                ))

                Toggle(Strings.prefs.batchSafeSync, isOn: Binding(
                    get: { prefs.batchSafeSyncEnabled },
                    set: { newValue in
                        prefs.batchSafeSyncEnabled = newValue
                        savePreferences()
                    }
                ))
                .help(Strings.prefs.batchSafeSyncHelp)
            }

            Section(Strings.prefs.notifications) {
                Toggle(Strings.prefs.enableNotifications, isOn: Binding(
                    get: { prefs.notificationsEnabled },
                    set: { newValue in
                        prefs.notificationsEnabled = newValue
                        savePreferences()
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property syncSettingsTab

    // MARK: - Tools Tab

    /// Tab for configuring tool paths (chezmoi, git, source repo, editor, merge tool).
    private var toolsTab: some View {
        Form {
            Section(Strings.prefs.chezmoi) {
                HStack {
                    TextField(Strings.prefs.chezmoiPath, text: Binding(
                        get: { prefs.chezmoiPathOverride ?? "" },
                        set: { newValue in
                            prefs.chezmoiPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(Strings.prefs.autoDetect) {
                        let detected = PATHResolver.chezmoiPath()
                        detectedChezmoiPath = detected
                        prefs.chezmoiPathOverride = detected
                        savePreferences()
                    }
                }

                if let path = detectedChezmoiPath {
                    Text(Strings.prefs.detected(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Strings.prefs.notFound)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(Strings.prefs.git) {
                HStack {
                    TextField(Strings.prefs.gitPath, text: Binding(
                        get: { prefs.gitPathOverride ?? "" },
                        set: { newValue in
                            prefs.gitPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(Strings.prefs.autoDetect) {
                        let detected = PATHResolver.gitPath()
                        detectedGitPath = detected
                        prefs.gitPathOverride = detected
                        savePreferences()
                    }
                }

                if let path = detectedGitPath {
                    Text(Strings.prefs.detected(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Strings.prefs.notFound)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(Strings.prefs.sourceRepository) {
                HStack {
                    TextField(Strings.prefs.sourceRepoPath, text: Binding(
                        get: { prefs.sourceRepoPathOverride ?? "" },
                        set: { newValue in
                            prefs.sourceRepoPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(Strings.prefs.autoDetect) {
                        detectSourceRepoPath()
                        prefs.sourceRepoPathOverride = detectedSourceRepoPath
                        savePreferences()
                    }
                }

                if let path = detectedSourceRepoPath {
                    Text(Strings.prefs.detected(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Strings.prefs.notFoundChezmoi)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text(Strings.prefs.pathChangeRequiresRestart)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Section(Strings.prefs.externalTools) {
                ExternalToolPicker(
                    label: Strings.prefs.preferredEditor,
                    selection: Binding(
                        get: { prefs.preferredEditor ?? "" },
                        set: { newValue in
                            prefs.preferredEditor = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ),
                    options: ExternalToolPicker.commonEditors
                )

                ExternalToolPicker(
                    label: Strings.prefs.preferredMergeTool,
                    selection: Binding(
                        get: { prefs.preferredMergeTool ?? "" },
                        set: { newValue in
                            prefs.preferredMergeTool = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ),
                    options: ExternalToolPicker.commonMergeTools
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property toolsTab

    // MARK: - Advanced Tab

    /// Tab for login at startup and reset settings.
    private var advancedTab: some View {
        Form {
            Section(Strings.prefs.startup) {
                Toggle(Strings.prefs.launchAtLogin, isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { newValue in
                        prefs.launchAtLogin = newValue
                        savePreferences()
                        updateLoginItem(enabled: newValue)
                    }
                ))

                loginItemStatusView
            }

            Section(Strings.prefs.diagnostics) {
                Toggle(Strings.prefs.verboseDiagnostics, isOn: Binding(
                    get: { prefs.verboseDiagnosticsEnabled },
                    set: { newValue in
                        prefs.verboseDiagnosticsEnabled = newValue
                        savePreferences()
                    }
                ))
                .help(Strings.prefs.verboseDiagnosticsHelp)
            }

            Section(Strings.prefs.reset) {
                Button(Strings.prefs.resetAllSettings, role: .destructive) {
                    showingResetConfirmation = true
                }
                .confirmationDialog(
                    Strings.prefs.resetConfirmTitle,
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(Strings.prefs.reset, role: .destructive) {
                        appState.resetAllPreferences()
                        prefs = .defaults
                        updateLoginItem(enabled: false)
                    }
                    Button(Strings.navigation.cancel, role: .cancel) {}
                } message: {
                    Text(Strings.prefs.resetConfirmMessage)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property advancedTab

    // MARK: - Helpers

    /// Saves the local prefs copy to the app state store.
    private func savePreferences() {
        appState.updatePreferences(prefs)
    } // End of func savePreferences()

    /// UI helper that describes the current login item status and next action.
    @ViewBuilder
    private var loginItemStatusView: some View {
        switch loginItemStatus {
        case .enabled:
            Text(Strings.prefs.loginItemEnabled)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notRegistered:
            Text(Strings.prefs.loginItemDisabled)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .requiresApproval:
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.prefs.loginItemApprovalRequired)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button(Strings.prefs.openLoginItems) {
                    openLoginItemsSettings()
                }
                .buttonStyle(.link)
            }
        case .notFound:
            Text(Strings.prefs.loginItemNotFound)
                .font(.caption)
                .foregroundStyle(.red)
        @unknown default:
            Text(Strings.prefs.loginItemUnavailable)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let errorMessage = loginItemErrorMessage {
            Text(Strings.prefs.startupError(errorMessage))
                .font(.caption)
                .foregroundStyle(.red)
        }
    } // End of computed property loginItemStatusView

    /// Updates the login item registration via SMAppService.
    /// - Parameter enabled: Whether to register or unregister the login item.
    private func updateLoginItem(enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                // Re-register on enable so app updates replace stale helper registrations.
                if service.status == .enabled {
                    try? service.unregister()
                }
                try service.register()
            } else {
                if service.status == .enabled || service.status == .requiresApproval {
                    try service.unregister()
                }
            }
            loginItemErrorMessage = nil
        } catch {
            loginItemErrorMessage = error.localizedDescription
        }

        refreshLoginItemStatus()
    } // End of func updateLoginItem(enabled:)

    /// Refreshes the cached `SMAppService` status used by the startup UI.
    private func refreshLoginItemStatus() {
        loginItemStatus = SMAppService.mainApp.status
    } // End of func refreshLoginItemStatus()

    /// Opens the Login Items pane to let users approve a newly registered item.
    private func openLoginItemsSettings() {
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.users?LoginItems"
        ]

        for rawURL in settingsURLs {
            if let url = URL(string: rawURL), NSWorkspace.shared.open(url) {
                return
            }
        }
    } // End of func openLoginItemsSettings()

    /// Detects the source repo path by running chezmoi source-path.
    private func detectSourceRepoPath() {
        guard let chezmoiBinary = PATHResolver.chezmoiPath() else {
            detectedSourceRepoPath = nil
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: chezmoiBinary)
        process.arguments = ["source-path"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    detectedSourceRepoPath = path
                    return
                }
            }
        } catch {
            // Fall through to nil
        }

        detectedSourceRepoPath = nil
    } // End of func detectSourceRepoPath()
} // End of struct PreferencesView
