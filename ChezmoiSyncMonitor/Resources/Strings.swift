import Foundation

/// Centralized namespace for all user-facing localized strings.
///
/// All UI text lives here so translators only need to update this file
/// and `Localizable.strings`. Each nested enum groups strings by feature area.
///
/// Usage: `Strings.onboarding.welcome` returns the localized string for the
/// "onboarding.welcome" key from `Localizable.strings`.
enum Strings {

    // MARK: - States

    /// Display names for file sync states used as overrides in the UI.
    enum states {
        /// Label shown when the local file does not exist on disk.
        static var localMissing: String {
            String(localized: "state.localMissing",
                   defaultValue: "Local File Not Found")
        }
    } // End of enum states

    // MARK: - Onboarding

    /// Strings for the onboarding wizard shown on first launch.
    enum onboarding {
        static var welcome: String {
            String(localized: "onboarding.welcome",
                   defaultValue: "Welcome to Chezmoi Sync Monitor")
        }
        static var welcomeDescription: String {
            String(localized: "onboarding.welcomeDescription",
                   defaultValue: "A lightweight menu bar utility that monitors your chezmoi-managed dotfiles for sync state across machines. It detects local drift, remote drift, and conflict risks, providing contextual actions to resolve them.")
        }
        static var checkDependencies: String {
            String(localized: "onboarding.checkDependencies",
                   defaultValue: "Check Dependencies")
        }
        static var dependenciesDescription: String {
            String(localized: "onboarding.dependenciesDescription",
                   defaultValue: "The app needs chezmoi and git to be installed on your system.")
        }
        static var detect: String {
            String(localized: "onboarding.detect",
                   defaultValue: "Detect")
        }
        static var redetect: String {
            String(localized: "onboarding.redetect",
                   defaultValue: "Re-detect")
        }
        static var notifications: String {
            String(localized: "onboarding.notifications",
                   defaultValue: "Notifications")
        }
        static var notificationsDescription: String {
            String(localized: "onboarding.notificationsDescription",
                   defaultValue: "The app can notify you when drift or conflicts are detected in your dotfiles. This helps you stay aware of changes that need attention.")
        }
        static var notificationsEnabled: String {
            String(localized: "onboarding.notificationsEnabled",
                   defaultValue: "Notifications enabled")
        }
        static var enableNotifications: String {
            String(localized: "onboarding.enableNotifications",
                   defaultValue: "Enable Notifications")
        }
        static var allSet: String {
            String(localized: "onboarding.allSet",
                   defaultValue: "You're All Set")
        }
        static var installInstructions: String {
            String(localized: "onboarding.installInstructions",
                   defaultValue: "Install instructions")
        }
        static var sourceRepoNotFound: String {
            String(localized: "onboarding.sourceRepoNotFound",
                   defaultValue: "Not found — run 'chezmoi init' first")
        }
        static var notFound: String {
            String(localized: "onboarding.notFound",
                   defaultValue: "Not found")
        }
        static var enabled: String {
            String(localized: "onboarding.enabled",
                   defaultValue: "Enabled")
        }
        static var disabled: String {
            String(localized: "onboarding.disabled",
                   defaultValue: "Disabled")
        }
        static var sourceRepo: String {
            String(localized: "onboarding.sourceRepo",
                   defaultValue: "Source repo")
        }
        static var permissions: String {
            String(localized: "onboarding.permissions",
                   defaultValue: "Permissions")
        }
        static var permissionsDescription: String {
            String(localized: "onboarding.permissionsDescription",
                   defaultValue: "Grant permissions so the app can access your dotfiles and notify you of changes.")
        }
        static var fullDiskAccess: String {
            String(localized: "onboarding.fullDiskAccess",
                   defaultValue: "Full Disk Access")
        }
        static var fullDiskAccessDescription: String {
            String(localized: "onboarding.fullDiskAccessDescription",
                   defaultValue: "Required to read and write dotfiles managed by other applications.")
        }
        static var openSettings: String {
            String(localized: "onboarding.openSettings",
                   defaultValue: "Open Settings")
        }
        static var permissionsOptional: String {
            String(localized: "onboarding.permissionsOptional",
                   defaultValue: "These permissions are optional but recommended for full functionality.")
        }
    } // End of enum onboarding

    // MARK: - Navigation

    /// Strings for common navigation buttons.
    enum navigation {
        static var back: String {
            String(localized: "navigation.back",
                   defaultValue: "Back")
        }
        static var next: String {
            String(localized: "navigation.next",
                   defaultValue: "Next")
        }
        static var close: String {
            String(localized: "navigation.close",
                   defaultValue: "Close")
        }
        static var cancel: String {
            String(localized: "navigation.cancel",
                   defaultValue: "Cancel")
        }
        static var startMonitoring: String {
            String(localized: "navigation.startMonitoring",
                   defaultValue: "Start Monitoring")
        }
    } // End of enum navigation

    // MARK: - Dashboard

    /// Strings for the main dashboard window.
    enum dashboard {
        static var title: String {
            String(localized: "dashboard.title",
                   defaultValue: "Chezmoi Sync Monitor")
        }
        static var notRefreshedYet: String {
            String(localized: "dashboard.notRefreshedYet",
                   defaultValue: "Not refreshed yet")
        }
        static var refreshing: String {
            String(localized: "dashboard.refreshing",
                   defaultValue: "Refreshing...")
        }
        static var dataIsStale: String {
            String(localized: "dashboard.dataIsStale",
                   defaultValue: "Data is stale")
        }
        static var filter: String {
            String(localized: "dashboard.filter",
                   defaultValue: "Filter:")
        }
        static var search: String {
            String(localized: "dashboard.search",
                   defaultValue: "Search:")
        }
        static var filterByPath: String {
            String(localized: "dashboard.filterByPath",
                   defaultValue: "Filter by path...")
        }
        static var managedFiles: String {
            String(localized: "dashboard.managedFiles",
                   defaultValue: "Managed Files")
        }
        static var noManagedFiles: String {
            String(localized: "dashboard.noManagedFiles",
                   defaultValue: "No managed files found.")
        }
        static var clickRefresh: String {
            String(localized: "dashboard.clickRefresh",
                   defaultValue: "Click the refresh button to scan for changes.")
        }
        static var noFilesMatchFilter: String {
            String(localized: "dashboard.noFilesMatchFilter",
                   defaultValue: "No files match the current filter.")
        }
        static var clearFilters: String {
            String(localized: "dashboard.clearFilters",
                   defaultValue: "Clear Filters")
        }
        static var diffLoadError: String {
            String(localized: "dashboard.diffLoadError",
                   defaultValue: "Could not load diff. The file may be binary or not managed by chezmoi.")
        }
        static var noDifferences: String {
            String(localized: "dashboard.noDifferences",
                   defaultValue: "No differences found for this file.")
        }
        static var remoteDiffHeader: String {
            String(localized: "dashboard.remoteDiffHeader",
                   defaultValue: "── Remote changes (not yet pulled) ──")
        }
        static var binaryFile: String {
            String(localized: "dashboard.binaryFile",
                   defaultValue: "Binary file — textual diff is not available.")
        }
        static func diffError(_ detail: String) -> String {
            String(format: NSLocalizedString("dashboard.diffError", value: "Error loading diff: %@", comment: ""), detail)
        }
        static var remoteDeleted: String {
            String(localized: "dashboard.remoteDeleted",
                   defaultValue: "⚠ This file was deleted remotely. Applying will remove it locally.")
        }
        static var remoteNewFile: String {
            String(localized: "dashboard.remoteNewFile",
                   defaultValue: "✦ This is a new file added remotely. Applying will create it locally.")
        }
        static var remoteNewFileLocalExists: String {
            String(localized: "dashboard.remoteNewFileLocalExists",
                   defaultValue: "✦ This file was added to chezmoi tracking remotely. Applying will overwrite your local copy with the tracked version.")
        }
        static var remoteModified: String {
            String(localized: "dashboard.remoteModified",
                   defaultValue: "This file was modified remotely.")
        }
        static var applyRemoteChanges: String {
            String(localized: "dashboard.applyRemoteChanges",
                   defaultValue: "Apply Remote Changes")
        }
        static var apply: String {
            String(localized: "dashboard.apply",
                   defaultValue: "Apply")
        }
        static var createLocal: String {
            String(localized: "dashboard.createLocal",
                   defaultValue: "Create Local")
        }
        static var applyWarning: String {
            String(localized: "dashboard.applyWarning",
                   defaultValue: "This will overwrite your local file with the remote version. This action cannot be undone.")
        }
        /// Returns the localized last-refresh label with an interpolated relative time.
        static func lastRefresh(_ time: String) -> String {
            String(format: NSLocalizedString("dashboard.lastRefresh", value: "Last refresh: %@", comment: ""), time)
        }
        static func version(_ value: String) -> String {
            String(format: NSLocalizedString("dashboard.version", value: "Version: %@", comment: ""), value)
        }
        static var createLocalFile: String {
            String(localized: "dashboard.createLocalFile",
                   defaultValue: "Create Local File")
        }
        static var createLocalFileMessage: String {
            String(localized: "dashboard.createLocalFileMessage",
                   defaultValue: "This will create the local file from the tracked version in chezmoi.")
        }
        static var dropFilesHint: String {
            String(localized: "dashboard.dropFilesHint",
                   defaultValue: "Drop files here to add them to chezmoi tracking")
        }
    } // End of enum dashboard

    // MARK: - Dashboard Filters

    /// Display names for file filter dropdown options.
    enum filters {
        /// Display name for the "Needs Attention" filter (excludes clean files).
        static var needsAttention: String {
            String(localized: "filter.needsAttention",
                   defaultValue: "Needs Attention")
        }
        static var all: String {
            String(localized: "filter.all",
                   defaultValue: "All")
        }
        static var localDrift: String {
            String(localized: "filter.localDrift",
                   defaultValue: "Local Drift")
        }
        static var remoteDrift: String {
            String(localized: "filter.remoteDrift",
                   defaultValue: "Remote Drift")
        }
        static var dualDrift: String {
            String(localized: "filter.dualDrift",
                   defaultValue: "Dual Drift")
        }
        static var error: String {
            String(localized: "filter.error",
                   defaultValue: "Error")
        }
        static var clean: String {
            String(localized: "filter.clean",
                   defaultValue: "Clean")
        }
    } // End of enum filters

    // MARK: - Overview Cards

    /// Labels used in the overview card row on the dashboard.
    enum overviewCards {
        static var all: String {
            String(localized: "overview.all",
                   defaultValue: "All")
        }
        static var needsAttention: String {
            String(localized: "overview.needsAttention",
                   defaultValue: "Needs Attention")
        }
        static var localDrift: String {
            String(localized: "overview.localDrift",
                   defaultValue: "Local Drift")
        }
        static var remoteDrift: String {
            String(localized: "overview.remoteDrift",
                   defaultValue: "Remote Drift")
        }
        static var conflicts: String {
            String(localized: "overview.conflicts",
                   defaultValue: "Conflicts")
        }
        static var errors: String {
            String(localized: "overview.errors",
                   defaultValue: "Errors")
        }
    } // End of enum overviewCards

    // MARK: - File Actions (short button labels)

    /// Short button labels for file-level actions in the file list.
    enum fileActions {
        static var add: String {
            String(localized: "fileAction.add",
                   defaultValue: "Keep Local")
        }
        static var apply: String {
            String(localized: "fileAction.apply",
                   defaultValue: "Apply")
        }
        static var createLocal: String {
            String(localized: "fileAction.createLocal",
                   defaultValue: "Create Local")
        }
        static var diff: String {
            String(localized: "fileAction.diff",
                   defaultValue: "Diff")
        }
        static var edit: String {
            String(localized: "fileAction.edit",
                   defaultValue: "Edit")
        }
        static var merge: String {
            String(localized: "fileAction.merge",
                   defaultValue: "Merge")
        }
        static var revert: String {
            String(localized: "fileAction.revert",
                   defaultValue: "Keep Remote")
        }
        static var forget: String {
            String(localized: "fileAction.forget",
                   defaultValue: "Forget")
        }

        // Tooltip hints
        static var addHint: String {
            String(localized: "fileAction.addHint",
                   defaultValue: "Keep the local version as the tracked version in chezmoi")
        }
        static var applyHint: String {
            String(localized: "fileAction.applyHint",
                   defaultValue: "Overwrite local file with the remote tracked version")
        }
        static var createLocalHint: String {
            String(localized: "fileAction.createLocalHint",
                   defaultValue: "Create the missing local file from the tracked remote version")
        }
        static var diffHint: String {
            String(localized: "fileAction.diffHint",
                   defaultValue: "Show differences between local file and tracked version")
        }
        static var editHint: String {
            String(localized: "fileAction.editHint",
                   defaultValue: "Open the local file in your preferred editor")
        }
        static var mergeHint: String {
            String(localized: "fileAction.mergeHint",
                   defaultValue: "Open both versions side-by-side in a merge tool")
        }
        static var revertHint: String {
            String(localized: "fileAction.revertHint",
                   defaultValue: "Discard local changes and keep the tracked remote version")
        }
        static var forgetHint: String {
            String(localized: "fileAction.forgetHint",
                   defaultValue: "Stop tracking this file — affects all machines sharing this chezmoi repository")
        }
    } // End of enum fileActions

    // MARK: - Confirmations

    /// Strings for destructive-action confirmation dialogs.
    enum confirmations {
        // Revert confirmation
        static var revertTitle: String {
            String(localized: "confirmation.revertTitle",
                   defaultValue: "Keep remote version?")
        }
        static var revertMessage: String {
            String(localized: "confirmation.revertMessage",
                   defaultValue: "This will overwrite your local file and keep the tracked remote version. This cannot be undone.")
        }
        static var revertButton: String {
            String(localized: "confirmation.revertButton",
                   defaultValue: "Keep Remote")
        }

        // Forget confirmation - step 1
        static var forgetTitle: String {
            String(localized: "confirmation.forgetTitle",
                   defaultValue: "Stop tracking this file?")
        }
        static var forgetMessage: String {
            String(localized: "confirmation.forgetMessage",
                   defaultValue: "This removes the file from chezmoi tracking. Future sync operations will ignore it.")
        }
        static var forgetContinue: String {
            String(localized: "confirmation.forgetContinue",
                   defaultValue: "Continue")
        }

        // Forget confirmation - step 2 (typed gate)
        static var forgetConfirmTitle: String {
            String(localized: "confirmation.forgetConfirmTitle",
                   defaultValue: "Confirm forget")
        }
        /// Returns the confirmation prompt with the token the user must type.
        static func forgetConfirmMessage(_ token: String) -> String {
            String(format: NSLocalizedString("confirmation.forgetConfirmMessage", value: "Type %@ to confirm:", comment: ""), token)
        }
        static var forgetConfirmPlaceholder: String {
            String(localized: "confirmation.forgetConfirmPlaceholder",
                   defaultValue: "Type FORGET to confirm")
        }
        static var forgetConfirmButton: String {
            String(localized: "confirmation.forgetConfirmButton",
                   defaultValue: "Forget File")
        }
        static var forgetConfirmMismatch: String {
            String(localized: "confirmation.forgetConfirmMismatch",
                   defaultValue: "Text does not match. Please type FORGET exactly.")
        }
    } // End of enum confirmations

    // MARK: - Safety / Read-only mode

    /// Strings for runtime safety gates that disable mutating actions.
    enum safety {
        static var viewOnlyTitle: String {
            String(localized: "safety.viewOnlyTitle",
                   defaultValue: "View-only mode")
        }
        static var enabledValue: String {
            String(localized: "safety.enabledValue",
                   defaultValue: "true")
        }
        static var disabledValue: String {
            String(localized: "safety.disabledValue",
                   defaultValue: "false")
        }
        /// Returns the read-only warning when git automation flags are explicitly disabled.
        static func gitAutomationDisabled(autoCommit: Bool, autoPush: Bool) -> String {
            let autoCommitText = autoCommit ? enabledValue : disabledValue
            let autoPushText = autoPush ? enabledValue : disabledValue
            return String(
                format: NSLocalizedString(
                    "safety.gitAutomationDisabled",
                    value: "Read-only mode is active because chezmoi requires git.autocommit=true and git.autopush=true. Current values: autocommit=%@, autopush=%@. Running without both can cause unexpected behaviors and sync states.",
                    comment: ""
                ),
                autoCommitText,
                autoPushText
            )
        }
        /// Returns the read-only warning when settings cannot be verified.
        static func gitAutomationUnknown(_ detail: String) -> String {
            String(
                format: NSLocalizedString(
                    "safety.gitAutomationUnknown",
                    value: "Read-only mode is active because the app could not verify chezmoi git.autocommit/autopush (%@). Running without this verification can cause unexpected behaviors and sync states.",
                    comment: ""
                ),
                detail
            )
        }
    } // End of enum safety

    // MARK: - Activity Log

    /// Strings for the collapsible activity log panel.
    enum activityLog {
        static var title: String {
            String(localized: "activityLog.title",
                   defaultValue: "Activity Log")
        }
        static var noActivity: String {
            String(localized: "activityLog.noActivity",
                   defaultValue: "No activity recorded yet.")
        }
    } // End of enum activityLog

    // MARK: - Diff Viewer

    /// Strings for the diff viewer sheet.
    enum diffViewer {
        /// Returns the localized diff header with an interpolated file path.
        static func title(_ path: String) -> String {
            String(format: NSLocalizedString("diffViewer.title", value: "Diff: %@", comment: ""), path)
        }
    } // End of enum diffViewer

    // MARK: - Menu Bar

    /// Strings for the menu bar dropdown.
    enum menu {
        static var title: String {
            String(localized: "menu.title",
                   defaultValue: "Chezmoi Sync Monitor")
        }
        static var refreshing: String {
            String(localized: "menu.refreshing",
                   defaultValue: "Refreshing...")
        }
        static var never: String {
            String(localized: "menu.never",
                   defaultValue: "Never")
        }
        static var quit: String {
            String(localized: "menu.quit",
                   defaultValue: "Quit")
        }
        static var offline: String {
            String(localized: "menu.offline",
                   defaultValue: "Offline")
        }
        static func lastCheck(_ time: String) -> String {
            String(format: NSLocalizedString("menu.lastCheck", value: "Last check: %@", comment: ""), time)
        }
        /// Returns the localized last-refresh label.
        static func lastRefresh(_ time: String) -> String {
            String(format: NSLocalizedString("menu.lastRefresh", value: "Last refresh: %@", comment: ""), time)
        }
        static func version(_ value: String) -> String {
            String(format: NSLocalizedString("menu.version", value: "Version: %@", comment: ""), value)
        }
        static var localChangeSingular: String {
            String(localized: "menu.localChange",
                   defaultValue: "local change")
        }
        static var localChangePlural: String {
            String(localized: "menu.localChanges",
                   defaultValue: "local changes")
        }
        static var remoteChangeSingular: String {
            String(localized: "menu.remoteChange",
                   defaultValue: "remote change")
        }
        static var remoteChangePlural: String {
            String(localized: "menu.remoteChanges",
                   defaultValue: "remote changes")
        }
        static var conflictSingular: String {
            String(localized: "menu.conflict",
                   defaultValue: "conflict")
        }
        static var conflictPlural: String {
            String(localized: "menu.conflicts",
                   defaultValue: "conflicts")
        }
        static var errorSingular: String {
            String(localized: "menu.error",
                   defaultValue: "error")
        }
        static var errorPlural: String {
            String(localized: "menu.errors",
                   defaultValue: "errors")
        }
        static var allClean: String {
            String(localized: "menu.allClean",
                   defaultValue: "All files in sync")
        }
        static var refreshNow: String {
            String(localized: "menu.refreshNow",
                   defaultValue: "Refresh Now")
        }
        static var addLocalChanges: String {
            String(localized: "menu.addLocalChanges",
                   defaultValue: "Add Local Changes")
        }
        static var commitAndPush: String {
            String(localized: "menu.commitAndPush",
                   defaultValue: "Commit & Push")
        }
        static var applySafeRemote: String {
            String(localized: "menu.applySafeRemote",
                   defaultValue: "Apply Safe Remote")
        }
        static var openDashboard: String {
            String(localized: "menu.openDashboard",
                   defaultValue: "Open Dashboard")
        }
        static var preferences: String {
            String(localized: "menu.preferences",
                   defaultValue: "Preferences...")
        }
    } // End of enum menu

    // MARK: - Diagnostics

    /// Strings for verbose debug diagnostics in Activity Log.
    enum diagnostics {
        static var refreshStart: String {
            String(localized: "diagnostics.refreshStart",
                   defaultValue: "[debug] Refresh started")
        }
        static var refreshValidateAutomation: String {
            String(localized: "diagnostics.refreshValidateAutomation",
                   defaultValue: "[debug] Step 1/7: validate git automation mode")
        }
        static var refreshGitFetch: String {
            String(localized: "diagnostics.refreshGitFetch",
                   defaultValue: "[debug] Step 2/7: git fetch")
        }
        static var refreshChezmoiStatus: String {
            String(localized: "diagnostics.refreshChezmoiStatus",
                   defaultValue: "[debug] Step 3/7: chezmoi status")
        }
        static var refreshTrackedFiles: String {
            String(localized: "diagnostics.refreshTrackedFiles",
                   defaultValue: "[debug] Step 4/7: tracked files")
        }
        static var refreshAheadBehind: String {
            String(localized: "diagnostics.refreshAheadBehind",
                   defaultValue: "[debug] Step 5/7: git ahead/behind")
        }
        static var refreshRemoteChanged: String {
            String(localized: "diagnostics.refreshRemoteChanged",
                   defaultValue: "[debug] Step 6/7: remote changed files")
        }
        static var refreshClassify: String {
            String(localized: "diagnostics.refreshClassify",
                   defaultValue: "[debug] Step 7/7: classify snapshot")
        }
        static var refreshComplete: String {
            String(localized: "diagnostics.refreshComplete",
                   defaultValue: "[debug] Refresh pipeline completed")
        }
        static func refreshStepResult(_ detail: String) -> String {
            String(
                format: NSLocalizedString(
                    "diagnostics.refreshStepResult",
                    value: "[debug] %@",
                    comment: ""
                ),
                detail
            )
        }
    } // End of enum diagnostics

    // MARK: - Preferences

    /// Strings for the preferences/settings window.
    enum prefs {
        // Tab labels
        static var syncTab: String {
            String(localized: "prefs.syncTab",
                   defaultValue: "Sync")
        }
        static var toolsTab: String {
            String(localized: "prefs.toolsTab",
                   defaultValue: "Tools")
        }
        static var advancedTab: String {
            String(localized: "prefs.advancedTab",
                   defaultValue: "Advanced")
        }

        // Sync tab
        static var polling: String {
            String(localized: "prefs.polling",
                   defaultValue: "Polling")
        }
        static var pollInterval: String {
            String(localized: "prefs.pollInterval",
                   defaultValue: "Poll interval:")
        }
        static var behavior: String {
            String(localized: "prefs.behavior",
                   defaultValue: "Behavior")
        }
        static var batchSafeSync: String {
            String(localized: "prefs.batchSafeSync",
                   defaultValue: "Batch safe sync")
        }
        static var batchSafeSyncHelp: String {
            String(localized: "prefs.batchSafeSyncHelp",
                   defaultValue: "Show batch \"Apply Safe Remote\" action in the menu bar")
        }
        static var autoApplyRemote: String {
            String(localized: "prefs.autoApplyRemote",
                   defaultValue: "Auto-apply remote changes")
        }
        static var autoApplyRemoteHelp: String {
            String(localized: "prefs.autoApplyRemoteHelp",
                   defaultValue: "Automatically apply remote-only changes after each refresh. Conflicts (dual drift) are never auto-applied.")
        }
        static var notifications: String {
            String(localized: "prefs.notifications",
                   defaultValue: "Notifications")
        }
        static var enableNotifications: String {
            String(localized: "prefs.enableNotifications",
                   defaultValue: "Enable notifications")
        }

        // Tools tab
        static var chezmoi: String {
            String(localized: "prefs.chezmoi",
                   defaultValue: "Chezmoi")
        }
        static var chezmoiPath: String {
            String(localized: "prefs.chezmoiPath",
                   defaultValue: "Chezmoi path:")
        }
        static var git: String {
            String(localized: "prefs.git",
                   defaultValue: "Git")
        }
        static var gitPath: String {
            String(localized: "prefs.gitPath",
                   defaultValue: "Git path:")
        }
        static var sourceRepository: String {
            String(localized: "prefs.sourceRepository",
                   defaultValue: "Source Repository")
        }
        static var sourceRepoPath: String {
            String(localized: "prefs.sourceRepoPath",
                   defaultValue: "Source repo path:")
        }
        static var autoDetect: String {
            String(localized: "prefs.autoDetect",
                   defaultValue: "Auto-detect")
        }
        /// Returns the localized "Detected: <path>" label.
        static func detected(_ path: String) -> String {
            String(format: NSLocalizedString("prefs.detected", value: "Detected: %@", comment: ""), path)
        }
        static var notFound: String {
            String(localized: "prefs.notFound",
                   defaultValue: "Not found")
        }
        static var notFoundChezmoi: String {
            String(localized: "prefs.notFoundChezmoi",
                   defaultValue: "Not found — is chezmoi initialized?")
        }
        static var externalTools: String {
            String(localized: "prefs.externalTools",
                   defaultValue: "External Tools")
        }
        static var preferredEditor: String {
            String(localized: "prefs.preferredEditor",
                   defaultValue: "Preferred editor:")
        }
        static var preferredMergeTool: String {
            String(localized: "prefs.preferredMergeTool",
                   defaultValue: "Preferred merge tool:")
        }

        // Advanced tab
        static var startup: String {
            String(localized: "prefs.startup",
                   defaultValue: "Startup")
        }
        static var launchAtLogin: String {
            String(localized: "prefs.launchAtLogin",
                   defaultValue: "Launch at login")
        }
        static var diagnostics: String {
            String(localized: "prefs.diagnostics",
                   defaultValue: "Diagnostics")
        }
        static var verboseDiagnostics: String {
            String(localized: "prefs.verboseDiagnostics",
                   defaultValue: "Verbose diagnostics logging")
        }
        static var verboseDiagnosticsHelp: String {
            String(localized: "prefs.verboseDiagnosticsHelp",
                   defaultValue: "Include detailed troubleshooting events in Activity Log (useful for support/debugging).")
        }
        static var reset: String {
            String(localized: "prefs.reset",
                   defaultValue: "Reset")
        }
        static var resetAllSettings: String {
            String(localized: "prefs.resetAllSettings",
                   defaultValue: "Reset All Settings")
        }
        static var resetConfirmTitle: String {
            String(localized: "prefs.resetConfirmTitle",
                   defaultValue: "Reset all settings to defaults?")
        }
        static var resetConfirmMessage: String {
            String(localized: "prefs.resetConfirmMessage",
                   defaultValue: "This will restore all preferences to their default values. This action cannot be undone.")
        }

        // Login item status
        static var loginItemEnabled: String {
            String(localized: "prefs.loginItemEnabled",
                   defaultValue: "Login item is enabled.")
        }
        static var loginItemDisabled: String {
            String(localized: "prefs.loginItemDisabled",
                   defaultValue: "Login item is disabled.")
        }
        static var loginItemApprovalRequired: String {
            String(localized: "prefs.loginItemApprovalRequired",
                   defaultValue: "Approval required in System Settings > General > Login Items.")
        }
        static var openLoginItems: String {
            String(localized: "prefs.openLoginItems",
                   defaultValue: "Open Login Items Settings")
        }
        static var loginItemNotFound: String {
            String(localized: "prefs.loginItemNotFound",
                   defaultValue: "Login item helper not found in this build.")
        }
        static var loginItemUnavailable: String {
            String(localized: "prefs.loginItemUnavailable",
                   defaultValue: "Login item status unavailable.")
        }
        /// Returns the localized startup error label.
        static func startupError(_ message: String) -> String {
            String(format: NSLocalizedString("prefs.startupError", value: "Last startup toggle error: %@", comment: ""), message)
        }

        static var pathChangeRequiresRestart: String {
            String(localized: "prefs.pathChangeRequiresRestart",
                   defaultValue: "Path changes take effect after restarting the app.")
        }

        // Config sync
        static var configSync: String {
            String(localized: "prefs.configSync",
                   defaultValue: "Configuration Sync")
        }
        static var addConfigToChezmoi: String {
            String(localized: "prefs.addConfigToChezmoi",
                   defaultValue: "Add Config to Chezmoi")
        }
        static var configTracked: String {
            String(localized: "prefs.configTracked",
                   defaultValue: "Config file is tracked by chezmoi and synced across machines.")
        }
        static var configNotTracked: String {
            String(localized: "prefs.configNotTracked",
                   defaultValue: "Config file is not tracked. Add it to sync preferences across machines.")
        }
        static var configCheckingStatus: String {
            String(localized: "prefs.configCheckingStatus",
                   defaultValue: "Checking tracking status...")
        }

        // Keyboard shortcut
        static var keyboardShortcut: String {
            String(localized: "prefs.keyboardShortcut",
                   defaultValue: "Dashboard Shortcut")
        }
        static var keyboardShortcutHelp: String {
            String(localized: "prefs.keyboardShortcutHelp",
                   defaultValue: "Set a global keyboard shortcut to open the dashboard from anywhere.")
        }
        static var shortcutNotSet: String {
            String(localized: "prefs.shortcutNotSet",
                   defaultValue: "Not set")
        }
        static var shortcutRecord: String {
            String(localized: "prefs.shortcutRecord",
                   defaultValue: "Record Shortcut")
        }
        static var shortcutRecording: String {
            String(localized: "prefs.shortcutRecording",
                   defaultValue: "Press shortcut...")
        }
        static var shortcutStop: String {
            String(localized: "prefs.shortcutStop",
                   defaultValue: "Cancel")
        }
        static var shortcutClear: String {
            String(localized: "prefs.shortcutClear",
                   defaultValue: "Clear")
        }
        static var shortcutConflictWarning: String {
            String(localized: "prefs.shortcutConflictWarning",
                   defaultValue: "This shortcut may conflict with a system or common application shortcut.")
        }
        static var shortcutRegistrationFailed: String {
            String(localized: "prefs.shortcutRegistrationFailed",
                   defaultValue: "Could not register this shortcut. It may already be in use by another application.")
        }

        // Poll interval labels
        static var manualOnly: String {
            String(localized: "prefs.manualOnly",
                   defaultValue: "Manual only")
        }
        /// Returns the localized poll interval label (e.g., "5 min").
        static func pollMinutes(_ n: Int) -> String {
            String(format: NSLocalizedString("prefs.pollMinutes", value: "%d min", comment: ""), n)
        }
    } // End of enum prefs

    // MARK: - External Tool Picker

    /// Strings for the external tool picker component.
    enum toolPicker {
        static var command: String {
            String(localized: "toolPicker.command",
                   defaultValue: "Command...")
        }
        static var ok: String {
            String(localized: "toolPicker.ok",
                   defaultValue: "OK")
        }
        static var defaultOption: String {
            String(localized: "toolPicker.default",
                   defaultValue: "(default)")
        }
        static var custom: String {
            String(localized: "toolPicker.custom",
                   defaultValue: "Custom...")
        }
        static var browse: String {
            String(localized: "toolPicker.browse",
                   defaultValue: "Browse...")
        }
        /// Returns the localized "Path: <path>" label.
        static func path(_ value: String) -> String {
            String(format: NSLocalizedString("toolPicker.path", value: "Path: %@", comment: ""), value)
        }
        static var notFoundOnSystem: String {
            String(localized: "toolPicker.notFoundOnSystem",
                   defaultValue: "Not found on this system")
        }
        static var selectTool: String {
            String(localized: "toolPicker.selectTool",
                   defaultValue: "Select tool")
        }
    } // End of enum toolPicker

    // MARK: - Notifications

    /// Strings for system notifications delivered via UNUserNotificationCenter.
    enum notifications {
        static var localChangesTitle: String {
            String(localized: "notification.localChangesTitle",
                   defaultValue: "Local Changes Detected")
        }
        /// Returns the notification body for local drift.
        static func localChangesBody(_ count: Int) -> String {
            String(format: NSLocalizedString("notification.localChangesBody", value: "%d file(s) have local changes not synced to source", comment: ""), count)
        }
        static var remoteChangesTitle: String {
            String(localized: "notification.remoteChangesTitle",
                   defaultValue: "Remote Changes Available")
        }
        /// Returns the notification body for remote drift.
        static func remoteChangesBody(_ count: Int) -> String {
            String(format: NSLocalizedString("notification.remoteChangesBody", value: "%d file(s) have remote changes available", comment: ""), count)
        }
        static var conflictsTitle: String {
            String(localized: "notification.conflictsTitle",
                   defaultValue: "Conflicting Changes")
        }
        /// Returns the notification body for conflicts.
        static func conflictsBody(_ count: Int) -> String {
            String(format: NSLocalizedString("notification.conflictsBody", value: "%d file(s) have conflicting changes", comment: ""), count)
        }
    } // End of enum notifications

    // MARK: - App-level

    /// Strings used at the top-level app scope.
    enum app {
        static var accessibilityLabel: String {
            String(localized: "app.accessibilityLabel",
                   defaultValue: "Chezmoi Sync Monitor")
        }
        static var unknownVersion: String {
            String(localized: "app.unknownVersion",
                   defaultValue: "unknown")
        }
    } // End of enum app

    // MARK: - Bundles

    /// Strings for the bundles feature (grouping tracked files).
    enum bundles {
        // Bundle management
        static var newBundle: String {
            String(localized: "bundles.newBundle",
                   defaultValue: "New Bundle")
        }
        static var renameBundle: String {
            String(localized: "bundles.renameBundle",
                   defaultValue: "Rename Bundle")
        }
        static var deleteBundle: String {
            String(localized: "bundles.deleteBundle",
                   defaultValue: "Delete Bundle")
        }
        static var bundleName: String {
            String(localized: "bundles.bundleName",
                   defaultValue: "Bundle Name")
        }
        static var bundleNamePlaceholder: String {
            String(localized: "bundles.bundleNamePlaceholder",
                   defaultValue: "Enter bundle name...")
        }
        static var manageBundles: String {
            String(localized: "bundles.manageBundles",
                   defaultValue: "Manage Bundles")
        }

        // Assignment
        static var assignToBundle: String {
            String(localized: "bundles.assignToBundle",
                   defaultValue: "Assign to Bundle")
        }
        static var removeFromBundle: String {
            String(localized: "bundles.removeFromBundle",
                   defaultValue: "Remove from Bundle")
        }
        static var unbundled: String {
            String(localized: "bundles.unbundled",
                   defaultValue: "Unbundled")
        }

        // Detail pane
        static var selectBundleHint: String {
            String(localized: "bundles.selectBundleHint",
                   defaultValue: "Select a bundle to see its files")
        }
        /// Returns the hint showing how many files are hidden by the current filter.
        static func filesHiddenByFilter(_ count: Int) -> String {
            String(format: NSLocalizedString("bundles.filesHiddenByFilter", value: "%d file(s) hidden by filter", comment: ""), count)
        }
        static var noMembers: String {
            String(localized: "bundles.noMembers",
                   defaultValue: "This bundle has no files")
        }
        static var allMembersFiltered: String {
            String(localized: "bundles.allMembersFiltered",
                   defaultValue: "All files in this bundle are hidden by the current filter")
        }

        // Confirmation dialogs
        static var deleteBundleTitle: String {
            String(localized: "bundles.deleteBundleTitle",
                   defaultValue: "Delete this bundle?")
        }
        static var deleteBundleMessage: String {
            String(localized: "bundles.deleteBundleMessage",
                   defaultValue: "The bundle will be removed but the files will remain tracked by chezmoi.")
        }
        static var deleteBundleButton: String {
            String(localized: "bundles.deleteBundleButton",
                   defaultValue: "Delete Bundle")
        }

        // Member count
        /// Returns a localized member count label.
        static func memberCount(_ count: Int) -> String {
            String(format: NSLocalizedString("bundles.memberCount", value: "%d file(s)", comment: ""), count)
        }

        // Multi-select
        /// Returns a label showing how many files are selected.
        static func selectionCount(_ count: Int) -> String {
            String(format: NSLocalizedString("bundles.selectionCount", value: "%d selected", comment: ""), count)
        }
        static var assignSelected: String {
            String(localized: "bundles.assignSelected",
                   defaultValue: "Assign Selected to Bundle")
        }
        static var clearSelection: String {
            String(localized: "bundles.clearSelection",
                   defaultValue: "Clear Selection")
        }
        static var selectAll: String {
            String(localized: "bundles.selectAll",
                   defaultValue: "Select All")
        }
    } // End of enum bundles
} // End of enum Strings
