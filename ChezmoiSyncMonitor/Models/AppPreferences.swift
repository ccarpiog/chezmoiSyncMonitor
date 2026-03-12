import Foundation

/// User-configurable preferences for the application.
///
/// Persisted as JSON via `Codable`. Includes a `schemaVersion` field to
/// support future migrations when the preference structure changes.
struct AppPreferences: Codable, Sendable, Equatable {
    /// Schema version for migration support. Increment when the structure changes.
    var schemaVersion: Int

    /// How often (in minutes) the app polls for changes. 0 means manual only.
    var pollIntervalMinutes: Int

    /// Whether system notifications are enabled for drift detection.
    var notificationsEnabled: Bool

    /// Whether the app automatically fetches from the remote repository.
    var autoFetchEnabled: Bool

    /// Whether batch safe-sync mode is enabled (sync all clean drifts at once).
    var batchSafeSyncEnabled: Bool

    /// Whether the app should launch at login.
    var launchAtLogin: Bool

    /// The name or path of the user's preferred merge tool, if any.
    var preferredMergeTool: String?

    /// The name or path of the user's preferred editor, if any.
    var preferredEditor: String?

    /// An optional override for the chezmoi binary path.
    var chezmoiPathOverride: String?

    /// An optional override for the git binary path.
    var gitPathOverride: String?

    /// An optional override for the chezmoi source repository path.
    var sourceRepoPathOverride: String?

    /// Whether verbose diagnostics should be logged in Activity Log at runtime.
    /// In Debug builds diagnostics are always enabled regardless of this value.
    var verboseDiagnosticsEnabled: Bool = false

    /// Default preferences with sensible initial values.
    static let defaults = AppPreferences(
        schemaVersion: 1,
        pollIntervalMinutes: 5,
        notificationsEnabled: true,
        autoFetchEnabled: true,
        batchSafeSyncEnabled: false,
        launchAtLogin: false,
        preferredMergeTool: nil,
        preferredEditor: nil,
        chezmoiPathOverride: nil,
        gitPathOverride: nil,
        sourceRepoPathOverride: nil,
        verboseDiagnosticsEnabled: false
    )
} // End of struct AppPreferences
