import Foundation

/// Describes an action that can be performed on a file to resolve sync issues.
enum FileAction: String, Sendable, Codable {
    case syncLocal
    case applyRemote
    case viewDiff
    case openEditor
    case openMergeTool
    case revertLocal
    case forgetFile

    /// A human-readable label for this action (English).
    var displayName: String {
        switch self {
        case .syncLocal:
            return String(localized: "action.syncLocal", defaultValue: "Sync Local Changes")
        case .applyRemote:
            return String(localized: "action.applyRemote", defaultValue: "Apply Remote Changes")
        case .viewDiff:
            return String(localized: "action.viewDiff", defaultValue: "View Diff")
        case .openEditor:
            return String(localized: "action.openEditor", defaultValue: "Open in Editor")
        case .openMergeTool:
            return String(localized: "action.openMergeTool", defaultValue: "Open Merge Tool")
        case .revertLocal:
            return String(localized: "action.revertLocal", defaultValue: "Revert to Tracked Version")
        case .forgetFile:
            return String(localized: "action.forgetFile", defaultValue: "Forget File")
        }
    } // End of computed property displayName
} // End of enum FileAction

/// Represents the sync status of a single chezmoi-managed file.
///
/// Includes the file path, its current sync state, the last modification date,
/// available resolution actions, and an optional error message.
struct FileStatus: Identifiable, Sendable {
    /// Unique identifier derived from the file path.
    var id: String { path }

    /// The relative path of the file within the chezmoi source directory.
    let path: String

    /// The current synchronization state of the file.
    let state: FileSyncState

    /// The date when the file was last modified locally, if known.
    let lastModified: Date?

    /// Actions available to the user for resolving this file's sync state.
    let availableActions: [FileAction]

    /// An optional error message if the file is in an error state.
    let errorMessage: String?

    /// Whether the local file is missing from disk (chezmoi destination status 'A').
    /// When `true`, the file exists in the chezmoi source state but has not been
    /// created at the destination yet.
    let localMissing: Bool

    /// Creates a new FileStatus instance.
    /// - Parameters:
    ///   - path: The relative path of the file.
    ///   - state: The synchronization state.
    ///   - lastModified: The last modification date, if known.
    ///   - availableActions: Actions available for this file.
    ///   - errorMessage: An optional error message.
    ///   - localMissing: Whether the local file does not exist on disk.
    init(
        path: String,
        state: FileSyncState,
        lastModified: Date? = nil,
        availableActions: [FileAction] = [],
        errorMessage: String? = nil,
        localMissing: Bool = false
    ) {
        self.path = path
        self.state = state
        self.lastModified = lastModified
        self.availableActions = availableActions
        self.errorMessage = errorMessage
        self.localMissing = localMissing
    } // End of init
} // End of struct FileStatus
