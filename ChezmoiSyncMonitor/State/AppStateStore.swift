import Foundation
import Observation

/// The single source of truth for all UI-facing application state.
///
/// Coordinates chezmoi and git service calls, maintains the current sync
/// snapshot, tracks refresh state, and manages the activity log and preferences.
/// All properties are observable for SwiftUI binding.
@MainActor
@Observable
final class AppStateStore {

    // MARK: - Published state

    /// The current synchronization snapshot across all managed files.
    var snapshot: SyncSnapshot = .empty

    /// The current refresh operation state.
    var refreshState: RefreshState = .idle

    /// Recent activity events, bounded to the last 500 entries.
    var activityLog: [ActivityEvent] = []

    /// User preferences for the application.
    var preferences: AppPreferences = .defaults

    /// Whether the network is currently reachable.
    var isOnline: Bool = true

    /// The loaded diff text for the diff viewer, if any.
    var currentDiff: String?

    // MARK: - Dependencies

    /// Service for interacting with the chezmoi CLI.
    private let chezmoiService: ChezmoiServiceProtocol

    /// Service for interacting with git in the source repo.
    private let gitService: GitServiceProtocol

    /// Engine for classifying per-file sync states.
    private let fileStateEngine: FileStateEngineProtocol

    /// Coordinator that prevents overlapping refreshes.
    private let refreshCoordinator = RefreshCoordinator()

    /// Persistence store for activity events.
    private let activityLogStore = ActivityLogStore()

    /// Persistence store for user preferences.
    private let preferencesStore = PreferencesStore()

    /// Background watcher that triggers periodic and event-driven refreshes.
    private var watcherService: WatcherServiceProtocol?

    /// Service for delivering macOS user notifications on drift detection.
    private var notificationService: NotificationServiceProtocol?

    /// Store for reading/writing the config file at ~/.config/chezmoiSyncMonitor/config.json.
    private let configFileStore = ConfigFileStore()

    /// Watcher that monitors the config file directory for external changes.
    private var configFileWatcher: ConfigFileWatcher?

    /// Maximum number of activity events to retain.
    private static let maxActivityEvents = 500

    /// Maximum duration (in seconds) for a single refresh pipeline before timing out.
    private static let refreshTimeoutSeconds: TimeInterval = 60

    /// Remote-changed files from the last fetch that have not yet been applied.
    ///
    /// After `pullSource()`, `behind` drops to 0 so `remoteChangedFiles()` returns
    /// empty. Without this sticky set, the refresh pipeline would reclassify
    /// unapplied remote files as `localDrift`, making destructive "Add" available.
    /// Entries are removed once they no longer appear in `chezmoi status` (i.e.,
    /// the apply succeeded and the file is clean).
    private var pendingRemoteFiles: Set<String> = []

    // MARK: - Initialization

    /// Creates a new AppStateStore with the given service dependencies.
    /// - Parameters:
    ///   - chezmoiService: The chezmoi CLI service.
    ///   - gitService: The git CLI service.
    ///   - fileStateEngine: The file state classification engine.
    ///   - watcherService: Optional watcher service override (for testing).
    ///   - notificationService: Optional notification service override (for testing).
    init(
        chezmoiService: ChezmoiServiceProtocol,
        gitService: GitServiceProtocol,
        fileStateEngine: FileStateEngineProtocol,
        watcherService: WatcherServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.chezmoiService = chezmoiService
        self.gitService = gitService
        self.fileStateEngine = fileStateEngine
        self.watcherService = watcherService
        self.notificationService = notificationService
    } // End of init(chezmoiService:gitService:fileStateEngine:watcherService:notificationService:)

    // MARK: - Service lifecycle

    /// Creates default WatcherService and NotificationService (if not injected)
    /// and starts background monitoring. Also requests notification authorization.
    ///
    /// Should be called once after the store is fully initialized (e.g., from the App struct).
    func startServices() async {
        // Load persisted preferences at startup.
        // Must happen BEFORE bootstrapping the config file so existing UserDefaults
        // preferences are migrated to the config file on first run (not overwritten by defaults).
        loadPreferences()

        // Ensure config file exists — bootstrap with current (possibly migrated) preferences
        configFileStore.ensureFileExists(defaults: preferences)

        // Start watching the config file for external changes (e.g., chezmoi apply)
        startConfigFileWatcher()

        // Create notification service if not injected
        if notificationService == nil {
            let prefsStore = preferencesStore
            notificationService = NotificationService(
                isEnabled: { [prefsStore] in
                    prefsStore.load().notificationsEnabled
                }
            )
        }

        // Request notification authorization (best-effort)
        _ = try? await notificationService?.requestAuthorization()

        // Create watcher service if not injected
        if watcherService == nil {
            let prefsStore = preferencesStore
            watcherService = WatcherService(
                refreshAction: { [weak self] in
                    await self?.refresh()
                },
                getInterval: { [prefsStore] in
                    prefsStore.load().pollIntervalMinutes
                },
                onConnectivityChange: { [weak self] isOnline in
                    Task { @MainActor [weak self] in
                        self?.isOnline = isOnline
                    }
                }
            )
        }

        await watcherService?.start()
    } // End of func startServices()

    /// Stops all background services. Called on deinit.
    func stopServices() {
        watcherService?.stop()
        configFileWatcher?.stop()
        configFileWatcher = nil
    } // End of func stopServices()

    // MARK: - Refresh

    /// Performs a full refresh of the sync state.
    ///
    /// Pipeline:
    /// 1. Set refreshState to .running
    /// 2. Git fetch (if autoFetchEnabled)
    /// 3. Get chezmoi status
    /// 4. Get git ahead/behind
    /// 5. Get remote changed files (if behind > 0)
    /// 6. Classify files via FileStateEngine
    /// 7. Build SyncSnapshot
    /// 8. Set refreshState to .success
    /// 9. Log activity event
    /// 10. On error: set refreshState to .error, log error event
    func refresh() async {
        await refreshCoordinator.performIfIdle { [self] in
            await self.performRefresh()
        }
    } // End of func refresh()

    /// Performs a refresh bypassing the debounce window.
    /// Use after mutations (add, update) to ensure the UI updates immediately.
    private func forceRefresh() async {
        await refreshCoordinator.forcePerform { [self] in
            await self.performRefresh()
        }
    } // End of func forceRefresh()

    /// Internal refresh implementation, called by the coordinator.
    ///
    /// Wraps the pipeline in a timeout task. If the entire refresh exceeds
    /// `refreshTimeoutSeconds`, it is cancelled and the state is set to `.stale`.
    /// No automatic retry is attempted; the next poll cycle will handle it.
    private func performRefresh() async {
        refreshState = .running

        let refreshTask = Task {
            try await self.executeRefreshPipeline()
        }

        // Set up a timeout watchdog for the entire refresh pipeline
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(AppStateStore.refreshTimeoutSeconds * 1_000_000_000))
            refreshTask.cancel()
        }

        do {
            try await refreshTask.value
            timeoutTask.cancel()
        } catch is CancellationError {
            timeoutTask.cancel()
            refreshState = .stale
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Refresh timed out after \(Int(AppStateStore.refreshTimeoutSeconds)) seconds"
            ))
        } catch {
            timeoutTask.cancel()
            let appError: AppError
            if let ae = error as? AppError {
                appError = ae
            } else {
                appError = .unknown(error.localizedDescription)
            }
            refreshState = .error(appError)
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Refresh failed: \(appError.localizedDescription)"
            ))
        }
    } // End of func performRefresh()

    /// Executes the core refresh pipeline steps.
    ///
    /// Separated from `performRefresh` to allow wrapping with a timeout task.
    /// - Throws: `AppError` if any CLI command fails, or `CancellationError` if timed out.
    private func executeRefreshPipeline() async throws {
        // Step 2: Git fetch if enabled
        if preferences.autoFetchEnabled {
            _ = try await gitService.fetch()
        }

        try Task.checkCancellation()

        // Step 3: Get chezmoi status
        let localFiles = try await chezmoiService.status()

        try Task.checkCancellation()

        // Step 3b: Get chezmoi tracked files (degrade gracefully on failure)
        var trackedFiles: Set<String> = []
        do {
            trackedFiles = try await chezmoiService.trackedFiles()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .refresh,
                message: "Could not fetch tracked files, falling back to drift-only mode"
            ))
        }

        try Task.checkCancellation()

        // Step 4: Get git ahead/behind
        let (_, behind) = try await gitService.aheadBehind()

        try Task.checkCancellation()

        // Step 5: Get remote changed files if behind > 0
        var remoteChanged: Set<String>
        if behind > 0 {
            remoteChanged = try await gitService.remoteChangedFiles()
            // Store fresh remote set so it survives the post-pull behind=0 window
            pendingRemoteFiles = remoteChanged
        } else {
            remoteChanged = []
        }

        try Task.checkCancellation()

        // Merge in sticky pending remote files that haven't been applied yet.
        // Only prune the pending set when behind == 0 (post-pull window).
        // While still behind, keep the full pending set to avoid dropping
        // remote files that only appear in chezmoi status after pull.
        if behind == 0, !pendingRemoteFiles.isEmpty {
            let localPaths = Set(localFiles.map(\.path))
            let normalizedPending = Set(pendingRemoteFiles.map { FileStateEngine.normalizeSourcePath($0) })
            let stillPending = normalizedPending.intersection(localPaths)
            if !stillPending.isEmpty {
                // Keep pending entries whose normalized form still shows drift
                let resolvedPending = pendingRemoteFiles.filter { stillPending.contains(FileStateEngine.normalizeSourcePath($0)) }
                remoteChanged = remoteChanged.union(resolvedPending)
                pendingRemoteFiles = resolvedPending
            } else {
                // All pending files are now clean — clear the sticky set
                pendingRemoteFiles = []
            }
        } else if behind > 0 {
            // While still behind, merge full pending set into remote changed
            remoteChanged = remoteChanged.union(pendingRemoteFiles)
        }

        // Step 6: Classify files (includes clean tracked files when available)
        let classifiedFiles = fileStateEngine.classify(
            localFiles: localFiles,
            remoteBehind: behind,
            remoteChangedFiles: remoteChanged,
            trackedFiles: trackedFiles
        )

        // Step 7: Build snapshot
        let now = Date()
        snapshot = SyncSnapshot(
            lastRefreshAt: now,
            files: classifiedFiles
        )

        // Step 8: Set success state
        refreshState = .success(now)

        // Step 9: Log activity event
        let summary = buildRefreshSummary(from: classifiedFiles)
        appendEvent(ActivityEvent(
            eventType: .refresh,
            message: summary
        ))

        // Step 9b: Notify user of drift via system notifications
        await notificationService?.notifyDrift(snapshot: snapshot)
    } // End of func executeRefreshPipeline()

    // MARK: - File operations

    /// Adds a single file to the chezmoi source state.
    /// - Parameter path: The relative file path to add.
    func addSingle(path: String) async {
        do {
            _ = try await chezmoiService.add(path: path)
            appendEvent(ActivityEvent(
                eventType: .add,
                message: "Added \(path) to source state",
                relatedFilePath: path
            ))
            await forceRefresh()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to add \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }
    } // End of func addSingle(path:)

    /// Adds all safe files (localDrift only) to the chezmoi source state.
    ///
    /// Files with dualDrift or error states are excluded to avoid conflicts.
    func addAllSafe() async {
        let safeFiles = snapshot.files.filter { $0.state == .localDrift }

        guard !safeFiles.isEmpty else { return }

        var addedCount = 0
        for file in safeFiles {
            do {
                _ = try await chezmoiService.add(path: file.path)
                addedCount += 1
            } catch {
                appendEvent(ActivityEvent(
                    eventType: .error,
                    message: "Failed to add \(file.path): \(error.localizedDescription)",
                    relatedFilePath: file.path
                ))
            }
        } // End of loop adding safe files

        if addedCount > 0 {
            appendEvent(ActivityEvent(
                eventType: .add,
                message: "Batch added \(addedCount) file(s) to source state"
            ))
        }

        await forceRefresh()
    } // End of func addAllSafe()

    /// Applies remote changes for a single file.
    ///
    /// Revalidates that the file is still in an apply-safe state (`remoteDrift`
    /// or `dualDrift`) before executing. This prevents stale UI state from
    /// overwriting local edits that appeared between confirmation and execution.
    ///
    /// Pulls the source repo first (to sync remote changes locally), then
    /// applies only the specified file to the target state.
    /// - Parameter path: The relative file path to apply.
    func updateSingle(path: String) async {
        // Revalidate: ensure the file is still in an apply-safe state
        guard let currentFile = snapshot.files.first(where: { $0.path == path }),
              currentFile.state == .remoteDrift || currentFile.state == .dualDrift else {
            let reason = snapshot.files.first(where: { $0.path == path })?.state.displayName ?? "not found in snapshot"
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Apply aborted for \(path): file state is \(reason) since confirmation",
                relatedFilePath: path
            ))
            await forceRefresh()
            return
        }

        appendEvent(ActivityEvent(
            eventType: .update,
            message: "Applying remote changes for \(path)",
            relatedFilePath: path
        ))

        do {
            _ = try await chezmoiService.pullSource()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to pull source before applying \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
            await forceRefresh()
            return
        }

        do {
            _ = try await chezmoiService.apply(path: path)
            appendEvent(ActivityEvent(
                eventType: .update,
                message: "Applied remote changes for \(path)",
                relatedFilePath: path
            ))
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Apply failed for \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }

        await forceRefresh()
    } // End of func updateSingle(path:)

    /// Applies remote changes for safe files (remoteDrift only) using per-file apply.
    ///
    /// Revalidates each file's state before applying. Iterates over each remoteDrift
    /// file independently so that a failure in one file does not block the others.
    func updateSafe() async {
        // Snapshot the files now and revalidate: only apply files still in remoteDrift
        let remoteFiles = snapshot.files.filter { $0.state == .remoteDrift }

        guard !remoteFiles.isEmpty else { return }

        appendEvent(ActivityEvent(
            eventType: .update,
            message: "Applying remote changes for \(remoteFiles.count) file(s)"
        ))

        // Pull source repo first so apply sees latest remote state
        do {
            _ = try await chezmoiService.pullSource()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to pull source before batch apply: \(error.localizedDescription)"
            ))
            await forceRefresh()
            return
        }

        var succeeded = 0
        var failed = 0
        var skipped = 0
        for file in remoteFiles {
            // Revalidate: re-check current snapshot state before each apply
            if let current = snapshot.files.first(where: { $0.path == file.path }),
               current.state != .remoteDrift {
                skipped += 1
                continue
            }

            do {
                _ = try await chezmoiService.apply(path: file.path)
                succeeded += 1
            } catch {
                failed += 1
                appendEvent(ActivityEvent(
                    eventType: .error,
                    message: "Apply failed for \(file.path): \(error.localizedDescription)",
                    relatedFilePath: file.path
                ))
            }
        } // End of loop applying remote files

        var summary = "Batch apply complete: \(succeeded) succeeded, \(failed) failed"
        if skipped > 0 {
            summary += ", \(skipped) skipped (state changed)"
        }
        if succeeded > 0 || failed > 0 || skipped > 0 {
            appendEvent(ActivityEvent(
                eventType: .update,
                message: summary
            ))
        }

        await forceRefresh()
    } // End of func updateSafe()

    /// Reverts local changes for a single file to match the chezmoi source state.
    ///
    /// Revalidates that the file is still in `localDrift` state before executing.
    /// Pulls the source repo first (to ensure the latest remote state), then applies
    /// the file so the local copy matches the source.
    /// - Parameter path: The relative file path to revert.
    func revertLocal(path: String) async {
        // Revalidate: ensure the file is still in localDrift state
        guard let currentFile = snapshot.files.first(where: { $0.path == path }),
              currentFile.state == .localDrift else {
            let reason = snapshot.files.first(where: { $0.path == path })?.state.displayName ?? "not found in snapshot"
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Revert aborted for \(path): file state is \(reason) since confirmation",
                relatedFilePath: path
            ))
            await forceRefresh()
            return
        }

        appendEvent(ActivityEvent(
            eventType: .update,
            message: "Reverting local changes for \(path)",
            relatedFilePath: path
        ))

        do {
            _ = try await chezmoiService.pullSource()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to pull source before reverting \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
            await forceRefresh()
            return
        }

        do {
            _ = try await chezmoiService.apply(path: path)
            appendEvent(ActivityEvent(
                eventType: .update,
                message: "Reverted local changes for \(path)",
                relatedFilePath: path
            ))
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Revert failed for \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }

        await forceRefresh()
    } // End of func revertLocal(path:)

    /// Removes a single file from chezmoi tracking.
    ///
    /// Uses `chezmoi forget --force` to untrack the file without deleting the
    /// local copy. No state revalidation is performed — the UI confirmation
    /// flow serves as the safety gate.
    /// - Parameter path: The relative file path to forget.
    func forgetSingle(path: String) async {
        appendEvent(ActivityEvent(
            eventType: .update,
            message: "Forgetting \(path) from chezmoi tracking",
            relatedFilePath: path
        ))

        do {
            _ = try await chezmoiService.forget(path: path)
            appendEvent(ActivityEvent(
                eventType: .update,
                message: "Removed \(path) from chezmoi tracking",
                relatedFilePath: path
            ))
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Forget failed for \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }

        await forceRefresh()
    } // End of func forgetSingle(path:)

    /// Commits and pushes all changes in the chezmoi source repo to the remote.
    ///
    /// Uses `chezmoi git` under the hood. Logs success or failure as activity events.
    func commitAndPush() async {
        do {
            let hostname = ProcessInfo.processInfo.hostName
                .components(separatedBy: ".").first ?? "unknown"
            let message = "Update dotfiles from \(hostname)"
            try await chezmoiService.commitAndPush(message: message)
            appendEvent(ActivityEvent(
                eventType: .update,
                message: "Committed and pushed changes to remote"
            ))
            await forceRefresh()
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to commit & push: \(error.localizedDescription)"
            ))
        }
    } // End of func commitAndPush()

    /// Opens a file in the user's preferred editor.
    ///
    /// If `preferredEditor` is set, launches the editor with the file path.
    /// Otherwise, opens the file with the default macOS application via `open`.
    /// The external process is launched fire-and-forget (not awaited) so interactive
    /// editors like vim or long-running GUI editors are not killed by a timeout.
    /// - Parameter path: The relative file path to open.
    func openInEditor(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = (trimmed as NSString).expandingTildeInPath
        let absolutePath: String
        if expandedPath.hasPrefix("/") {
            absolutePath = expandedPath
        } else {
            absolutePath = (NSHomeDirectory() as NSString).appendingPathComponent(expandedPath)
        }

        do {
            guard FileManager.default.fileExists(atPath: absolutePath) else {
                throw AppError.unknown("File not found at \(absolutePath)")
            }

            let command: String
            let arguments: [String]
            let waitForExit: Bool

            if let editor = preferences.preferredEditor?.trimmingCharacters(in: .whitespacesAndNewlines),
               !editor.isEmpty {
                // Support app bundle paths selected from Browse... in Preferences.
                if editor.hasSuffix(".app") {
                    command = "/usr/bin/open"
                    arguments = ["-a", editor, absolutePath]
                    waitForExit = true
                } else {
                    let editorPath = PATHResolver.findExecutable(editor) ?? editor
                    if isTerminalEditorCommand(editorPath) {
                        let terminalCommand = commandDescription(command: editorPath, arguments: [absolutePath])
                        try launchInTerminal(shellCommand: terminalCommand)
                        appendEvent(ActivityEvent(
                            eventType: .refresh,
                            message: "Opened \(path) in terminal editor via Terminal: \(terminalCommand)",
                            relatedFilePath: path
                        ))
                        return
                    } else {
                        command = editorPath
                        arguments = [absolutePath]
                        waitForExit = false
                    }
                }
            } else {
                // Use text-editor mode to avoid app-association failures for file types like .plist.
                command = "/usr/bin/open"
                arguments = ["-t", absolutePath]
                waitForExit = true
            }

            let commandLine = commandDescription(command: command, arguments: arguments)
            try launchProcess(command: command, arguments: arguments, waitForExit: waitForExit)
            appendEvent(ActivityEvent(
                eventType: .refresh,
                message: "Opened \(path) in editor via \(commandLine)",
                relatedFilePath: path
            ))
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to open \(path) in editor: \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }
    } // End of func openInEditor(path:)

    /// Opens a file in the user's preferred merge tool with both local and source versions.
    ///
    /// Resolves the chezmoi source path for the file and launches the merge tool
    /// with both paths. Falls back to `opendiff` (macOS FileMerge) if no merge tool is set.
    /// The external process is launched fire-and-forget (not awaited).
    /// - Parameter path: The relative file path to merge.
    func openInMergeTool(path: String) async {
        let homePath = NSHomeDirectory()
        let localPath = path.hasPrefix("/") ? path : "\(homePath)/\(path)"

        do {
            let sourceFilePath = try await chezmoiService.sourcePath(for: path)
            let tool = preferences.preferredMergeTool?.isEmpty == false
                ? preferences.preferredMergeTool!
                : "opendiff"
            let toolPath = PATHResolver.findExecutable(tool) ?? tool
            var args = mergeToolExtraArgs(for: tool)
            args.append(contentsOf: [localPath, sourceFilePath])
            try launchProcess(command: toolPath, arguments: args)
            appendEvent(ActivityEvent(
                eventType: .refresh,
                message: "Opened \(path) in merge tool",
                relatedFilePath: path
            ))
        } catch {
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to open \(path) in merge tool: \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }
    } // End of func openInMergeTool(path:)

    /// Returns extra arguments needed for specific merge tools.
    ///
    /// Some tools require flags to enter diff/merge mode (e.g., VS Code needs `--diff`).
    /// - Parameter tool: The tool command name or path.
    /// - Returns: An array of extra arguments to prepend before the file paths.
    private func mergeToolExtraArgs(for tool: String) -> [String] {
        let base = URL(fileURLWithPath: tool).lastPathComponent
        switch base {
        case "code", "cursor":
            return ["--diff", "--wait"]
        case "nvim":
            return ["-d"]
        default:
            return []
        }
    } // End of func mergeToolExtraArgs(for:)

    /// Launches an external process without waiting for it to finish.
    ///
    /// Used for editor and merge tool launches where the process may stay open
    /// indefinitely while the user works.
    /// - Parameters:
    ///   - command: The path to the executable.
    ///   - arguments: The arguments to pass.
    ///   - waitForExit: Whether to wait for process completion and validate exit status.
    /// - Throws: If the process cannot be launched.
    private func launchProcess(command: String, arguments: [String], waitForExit: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        let stderrPipe = Pipe()
        if waitForExit {
            process.standardError = stderrPipe
        }
        let commandLine = commandDescription(command: command, arguments: arguments)

        do {
            try process.run()
        } catch {
            throw AppError.unknown("Failed to launch command '\(commandLine)': \(error.localizedDescription)")
        }

        if waitForExit {
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw AppError.cliFailure(
                    command: commandLine,
                    exitCode: process.terminationStatus,
                    stderr: stderr
                )
            }
        }
    } // End of func launchProcess(command:arguments:)

    /// Returns true if the editor command is terminal-bound and needs a terminal host.
    /// - Parameter command: Executable path or command name.
    /// - Returns: `true` for terminal editors (nano/vim/etc).
    private func isTerminalEditorCommand(_ command: String) -> Bool {
        let base = URL(fileURLWithPath: command).lastPathComponent.lowercased()
        return ["nano", "vim", "vi", "nvim", "emacs", "ed", "less", "more"].contains(base)
    } // End of func isTerminalEditorCommand(_:)

    /// Launches a shell command in Terminal.app.
    /// - Parameter shellCommand: The command line to run in a new Terminal tab.
    /// - Throws: If `osascript` fails.
    private func launchInTerminal(shellCommand: String) throws {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        try launchProcess(
            command: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"Terminal\" to activate",
                "-e", "tell application \"Terminal\" to do script \"\(escaped)\""
            ],
            waitForExit: true
        )
    } // End of func launchInTerminal(shellCommand:)

    /// Renders a shell-like command string for logs and diagnostics.
    /// - Parameters:
    ///   - command: The executable path/name.
    ///   - arguments: Command arguments.
    /// - Returns: A display-safe command line.
    private func commandDescription(command: String, arguments: [String]) -> String {
        func quoteIfNeeded(_ s: String) -> String {
            if s.isEmpty { return "\"\"" }
            let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/:")
            if s.rangeOfCharacter(from: safe.inverted) == nil {
                return s
            }
            return "\"" + s.replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }

        return ([command] + arguments).map(quoteIfNeeded).joined(separator: " ")
    } // End of func commandDescription(command:arguments:)

    /// Loads the diff text for a specific file path into `currentDiff`.
    /// - Parameter path: The relative file path to diff.
    func loadDiff(for path: String) async {
        do {
            let result = try await chezmoiService.diff(for: path)
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentDiff = "No differences found for this file."
            } else if result.contains("Binary files") && result.contains("differ") {
                currentDiff = "Binary file — textual diff is not available.\n\n\(result)"
            } else {
                currentDiff = result
            }
        } catch {
            currentDiff = "Error loading diff: \(error.localizedDescription)"
            appendEvent(ActivityEvent(
                eventType: .error,
                message: "Failed to load diff for \(path): \(error.localizedDescription)",
                relatedFilePath: path
            ))
        }
    } // End of func loadDiff(for:)

    // MARK: - Preferences

    /// Loads preferences from the persistence store.
    func loadPreferences() {
        preferences = preferencesStore.load()
    } // End of func loadPreferences()

    /// Saves current preferences to the persistence store.
    func savePreferences() {
        preferencesStore.save(preferences)
    } // End of func savePreferences()

    /// Updates preferences, saves them, and restarts the watcher if the poll interval changed.
    /// - Parameter prefs: The new preferences to apply.
    func updatePreferences(_ prefs: AppPreferences) {
        let oldInterval = preferences.pollIntervalMinutes
        preferences = prefs
        preferencesStore.save(prefs)

        // Restart watcher if poll interval changed
        if oldInterval != prefs.pollIntervalMinutes {
            watcherService?.stop()
            Task {
                await watcherService?.start()
            }
        }
    } // End of func updatePreferences(_:)

    /// Handles an external preference change detected by the config file watcher.
    ///
    /// Reloads the config file, merges cross-machine settings into current preferences
    /// (preserving per-machine values), and hot-applies changes. If the poll interval
    /// changed, the watcher service is restarted.
    /// - Parameter newPrefs: The updated preferences loaded from the config file.
    func handleExternalPreferenceChange(_ newPrefs: AppPreferences) {
        let oldInterval = preferences.pollIntervalMinutes

        // Only update if something actually changed
        guard newPrefs != preferences else { return }

        preferences = newPrefs

        // Cache to UserDefaults
        preferencesStore.save(newPrefs)

        appendEvent(ActivityEvent(
            eventType: .refresh,
            message: "Preferences updated from config file"
        ))

        // Restart watcher if poll interval changed
        if oldInterval != newPrefs.pollIntervalMinutes {
            watcherService?.stop()
            Task {
                await watcherService?.start()
            }
        }
    } // End of func handleExternalPreferenceChange(_:)

    /// Starts the config file watcher that monitors `~/.config/chezmoiSyncMonitor/` for changes.
    ///
    /// When the config file is modified externally (e.g., by `chezmoi apply`), the watcher
    /// reloads and hot-applies the new settings.
    private func startConfigFileWatcher() {
        configFileWatcher?.stop()

        configFileWatcher = ConfigFileWatcher(
            directory: configFileStore.configDirectory,
            fileURL: configFileStore.configFileURL
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Reload from config file
                guard let newConfig = self.configFileStore.load() else { return }

                // Merge with current per-machine settings
                let merged = self.configFileStore.merge(newConfig, into: self.preferences)

                self.handleExternalPreferenceChange(merged)
            }
        }

        configFileWatcher?.start()
    } // End of func startConfigFileWatcher()

    /// Returns whether the user has completed the first-launch onboarding.
    var hasCompletedOnboarding: Bool {
        preferencesStore.hasCompletedOnboarding()
    }

    /// Marks the first-launch onboarding as completed.
    func completeOnboarding() {
        preferencesStore.setOnboardingCompleted()
    } // End of func completeOnboarding()

    /// Resets all preferences to defaults.
    func resetAllPreferences() {
        preferencesStore.resetAll()
        preferences = .defaults
    } // End of func resetAllPreferences()

    // MARK: - Activity log

    /// Appends an event to the in-memory activity log, capping at 500 events.
    /// The log is session-only and not persisted across app launches.
    /// - Parameter event: The event to append.
    private func appendEvent(_ event: ActivityEvent) {
        activityLog.append(event)
        if activityLog.count > AppStateStore.maxActivityEvents {
            activityLog.removeFirst(activityLog.count - AppStateStore.maxActivityEvents)
        }
    } // End of func appendEvent(_:)

    /// Loads the activity log from disk persistence.
    func loadActivityLog() {
        do {
            activityLog = try activityLogStore.load()
        } catch {
            activityLog = []
        }
    } // End of func loadActivityLog()

    // MARK: - Helpers

    /// Builds a human-readable summary of a refresh result.
    /// - Parameter files: The classified file statuses.
    /// - Returns: A summary string.
    private func buildRefreshSummary(from files: [FileStatus]) -> String {
        let clean = files.filter { $0.state == .clean }.count
        let local = files.filter { $0.state == .localDrift }.count
        let remote = files.filter { $0.state == .remoteDrift }.count
        let dual = files.filter { $0.state == .dualDrift }.count
        let errors = files.filter { $0.state == .error }.count

        let driftFiles = local + remote + dual + errors
        if driftFiles == 0 {
            if clean > 0 {
                return "Refresh complete: all \(clean) tracked file(s) in sync"
            }
            return "Refresh complete: all files in sync"
        }

        var parts: [String] = []
        if local > 0 { parts.append("\(local) local") }
        if remote > 0 { parts.append("\(remote) remote") }
        if dual > 0 { parts.append("\(dual) conflict(s)") }
        if errors > 0 { parts.append("\(errors) error(s)") }
        if clean > 0 { parts.append("\(clean) clean") }

        return "Refresh complete: \(parts.joined(separator: ", "))"
    } // End of func buildRefreshSummary(from:)
} // End of class AppStateStore
