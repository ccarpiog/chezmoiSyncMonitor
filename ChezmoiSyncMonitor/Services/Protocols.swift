import Foundation

/// The state of chezmoi git automation settings used by mutating commands.
struct GitAutomationConfig: Equatable, Sendable {
    /// Whether `chezmoi` is configured to auto-commit source changes.
    let autoCommit: Bool

    /// Whether `chezmoi` is configured to auto-push source changes.
    let autoPush: Bool

    /// Whether both required automation switches are enabled.
    var isFullyEnabled: Bool {
        autoCommit && autoPush
    }
} // End of struct GitAutomationConfig

/// Protocol for interacting with the chezmoi CLI.
///
/// Provides methods to query file status, compute diffs, add local changes
/// to the source state, and apply remote updates.
protocol ChezmoiServiceProtocol: Sendable {
    /// Returns the sync status of all chezmoi-managed files.
    /// - Returns: An array of `FileStatus` values.
    /// - Throws: `AppError` if the chezmoi command fails.
    func status() async throws -> [FileStatus]

    /// Computes the diff for a specific file path.
    /// - Parameter path: The relative file path to diff.
    /// - Returns: A unified diff string.
    /// - Throws: `AppError` if the chezmoi command fails.
    func diff(for path: String) async throws -> String

    /// Adds a local file to the chezmoi source state.
    /// - Parameter path: The relative file path to add.
    /// - Returns: The result of the add command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func add(path: String) async throws -> CommandResult

    /// Applies remote changes from the source state to the local machine.
    /// - Returns: The result of the update command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func update() async throws -> CommandResult

    /// Pulls remote changes into the chezmoi source state without applying them.
    /// Uses a fast-forward-only pull in the source repo.
    /// - Returns: The result of the pull command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func pullSource() async throws -> CommandResult

    /// Applies the chezmoi source state for a single file to the local machine.
    /// Does NOT pull from remote — call `pullSource()` first if needed.
    /// - Parameter path: The relative file path to apply.
    /// - Returns: The result of the apply command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func apply(path: String) async throws -> CommandResult

    /// Stages, commits, and pushes changes in the chezmoi source repo via `chezmoi git`.
    /// - Parameter message: The commit message.
    /// - Throws: `AppError` if any git step fails.
    func commitAndPush(message: String) async throws

    /// Returns the chezmoi source-state file path for a given target path.
    /// - Parameter path: The relative target file path (e.g., `.bashrc`).
    /// - Returns: The absolute path to the corresponding file in the chezmoi source directory.
    /// - Throws: `AppError` if the chezmoi command fails.
    func sourcePath(for path: String) async throws -> String

    /// Returns the set of all chezmoi-managed file paths (relative to home).
    /// - Returns: A set of relative file paths managed by chezmoi.
    /// - Throws: `AppError` if the chezmoi command fails.
    func trackedFiles() async throws -> Set<String>

    /// Reads `chezmoi` git automation settings used by mutating operations.
    ///
    /// Required settings:
    /// - `git.autocommit = true`
    /// - `git.autopush = true`
    ///
    /// - Returns: Parsed automation flags from `chezmoi dump-config`.
    /// - Throws: `AppError` if config cannot be read or parsed.
    func gitAutomationConfig() async throws -> GitAutomationConfig

    /// Removes a file from chezmoi tracking (source state only; destination kept).
    /// - Parameter path: The relative file path to forget.
    /// - Returns: The result of the forget command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func forget(path: String) async throws -> CommandResult
} // End of protocol ChezmoiServiceProtocol

/// Protocol for interacting with git in the chezmoi source repository.
///
/// Provides methods to fetch from the remote and determine how far ahead
/// or behind the local branch is.
protocol GitServiceProtocol: Sendable {
    /// Fetches the latest refs from the remote repository.
    /// - Returns: The result of the fetch command.
    /// - Throws: `AppError` if the git command fails.
    func fetch() async throws -> CommandResult

    /// Returns how many commits the local branch is ahead and behind the remote.
    /// - Returns: A tuple with `ahead` and `behind` commit counts.
    /// - Throws: `AppError` if the git command fails.
    func aheadBehind() async throws -> (ahead: Int, behind: Int)

    /// Returns the set of file paths that changed in commits the local branch is behind on.
    /// - Returns: A set of relative file paths that differ between HEAD and upstream.
    /// - Throws: `AppError` if the git command fails.
    func remoteChangedFiles() async throws -> Set<String>

    /// Returns the unified diff of a specific source file between HEAD and upstream.
    /// - Parameter sourcePath: The absolute path to the file in the chezmoi source directory.
    /// - Returns: The diff output, or an empty string if there are no remote changes.
    /// - Throws: `AppError` if the git command fails.
    func remoteFileDiff(for sourcePath: String) async throws -> String
} // End of protocol GitServiceProtocol

/// Protocol for the engine that classifies file states based on local and
/// remote information.
protocol FileStateEngineProtocol: Sendable {
    /// Classifies file statuses by combining local chezmoi status with remote
    /// ahead/behind information.
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi.
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    /// - Returns: Updated file statuses with classified sync states.
    func classify(localFiles: [FileStatus], remoteBehind: Int) -> [FileStatus]

    /// Classifies file statuses by combining local chezmoi status with remote
    /// change information for per-file granularity.
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi.
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    ///   - remoteChangedFiles: The set of file paths that changed in remote commits.
    /// - Returns: Updated file statuses with classified sync states and actions.
    func classify(localFiles: [FileStatus], remoteBehind: Int, remoteChangedFiles: Set<String>) -> [FileStatus]

    /// Classifies file statuses by combining local chezmoi status, remote change
    /// information, and the full set of tracked files for per-file granularity.
    ///
    /// Tracked files that have no drift (neither local nor remote) are included
    /// in the result as `clean` entries, giving a complete picture of all managed files.
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi (files with drift).
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    ///   - remoteChangedFiles: The set of file paths that changed in remote commits.
    ///   - trackedFiles: The full set of chezmoi-managed file paths.
    /// - Returns: Updated file statuses with classified sync states and actions, including clean files.
    func classify(localFiles: [FileStatus], remoteBehind: Int, remoteChangedFiles: Set<String>, trackedFiles: Set<String>) -> [FileStatus]
} // End of protocol FileStateEngineProtocol

/// Protocol for the background watcher that triggers periodic refreshes.
protocol WatcherServiceProtocol: Sendable {
    /// Starts the watcher (polling, wake detection, network change monitoring).
    func start() async

    /// Stops the watcher and cancels all scheduled refreshes.
    func stop()
} // End of protocol WatcherServiceProtocol

/// Protocol for managing macOS user notifications.
protocol NotificationServiceProtocol: Sendable {
    /// Requests notification authorization from the user.
    /// - Returns: `true` if authorization was granted.
    /// - Throws: If the authorization request fails.
    func requestAuthorization() async throws -> Bool

    /// Sends a notification summarizing detected drift.
    /// - Parameter snapshot: The current sync snapshot.
    func notifyDrift(snapshot: SyncSnapshot) async
} // End of protocol NotificationServiceProtocol
