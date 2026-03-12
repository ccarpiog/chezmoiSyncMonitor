import Foundation

/// Implementation of `ChezmoiServiceProtocol` that wraps the chezmoi CLI.
///
/// Uses `ProcessRunner` to execute chezmoi commands and `PATHResolver`
/// to locate the chezmoi binary.
final class ChezmoiService: ChezmoiServiceProtocol, Sendable {

    /// The resolved path to the chezmoi executable.
    private let chezmoiBinary: String

    /// Creates a new ChezmoiService.
    ///
    /// - Parameter binaryPath: An optional explicit path to the chezmoi binary.
    ///   If `nil`, the path is resolved automatically via `PATHResolver`.
    /// - Throws: `AppError.unknown` if the chezmoi binary cannot be found.
    init(binaryPath: String? = nil) throws {
        if let path = binaryPath {
            self.chezmoiBinary = path
        } else {
            guard let resolved = PATHResolver.chezmoiPath() else {
                throw AppError.unknown("chezmoi binary not found in PATH")
            }
            self.chezmoiBinary = resolved
        }
    } // End of init(binaryPath:)

    /// Runs `chezmoi status` and parses the output into `FileStatus` objects.
    ///
    /// Chezmoi status format: each line is `XY path` where X = source change,
    /// Y = destination change. Letters: A (add), D (delete), M (modify), R (rename).
    ///
    /// - Returns: An array of `FileStatus` values representing files with drift.
    /// - Throws: `AppError` if the command fails or output cannot be parsed.
    func status() async throws -> [FileStatus] {
        // chezmoi status returns exit code 1 when there are differences,
        // so we don't throw on non-zero — we need the stdout output.
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["status"],
            throwOnFailure: false
        )

        // If there's real stderr output (not just a non-zero exit for diffs), report it
        if result.exitCode != 0 && result.exitCode != 1 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return ChezmoiService.parseStatusOutput(result.stdout)
    } // End of func status()

    /// Parses the raw output of `chezmoi status` into `FileStatus` objects.
    ///
    /// `chezmoi status` output format: each line is two status characters followed by a space
    /// and the file path. The characters indicate what would change if `chezmoi apply` were run.
    /// At this stage, all files with changes are marked as `localDrift` (local file differs
    /// from chezmoi source). The `FileStateEngine` (Phase 4) will reclassify states by
    /// combining this with git remote information.
    ///
    /// Exposed as an internal static method to allow unit testing without
    /// running the actual chezmoi binary.
    ///
    /// - Parameter output: The raw stdout from `chezmoi status`.
    /// - Returns: An array of parsed `FileStatus` values.
    static func parseStatusOutput(_ output: String) -> [FileStatus] {
        guard !output.isEmpty else { return [] }

        var results: [FileStatus] = []

        for line in output.components(separatedBy: .newlines) {
            guard line.count >= 3 else { continue }

            let firstChar = line[line.startIndex]
            let secondChar = line[line.index(after: line.startIndex)]
            let pathStartIndex = line.index(line.startIndex, offsetBy: 2)
            let path = String(line[pathStartIndex...]).trimmingCharacters(in: .whitespaces)

            guard !path.isEmpty else { continue }

            let hasChange = firstChar != " " || secondChar != " "

            // At this stage we only know local-vs-source drift from chezmoi.
            // Remote drift classification happens in FileStateEngine after git fetch.
            let state: FileSyncState = hasChange ? .localDrift : .clean

            // When the destination status char is 'A', the local file does not
            // exist on disk — chezmoi would need to Add (create) it.
            let isLocalMissing = secondChar == "A"

            var actions: [FileAction] = [.viewDiff]
            if state == .localDrift {
                actions.append(.syncLocal)
                actions.append(.openEditor)
            }

            results.append(FileStatus(
                path: path,
                state: state,
                availableActions: actions,
                localMissing: isLocalMissing
            ))
        } // End of loop through status output lines

        return results
    } // End of static func parseStatusOutput(_:)

    /// Computes the diff for a specific file path.
    ///
    /// - Parameter path: The relative file path to diff.
    /// - Returns: The unified diff string.
    /// - Throws: `AppError` if the chezmoi command fails.
    func diff(for path: String) async throws -> String {
        let resolvedPath = Self.resolveChezmoiTargetPath(path)
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["diff", "--", resolvedPath]
        )
        return result.stdout
    } // End of func diff(for:)

    /// Adds a local file to the chezmoi source state.
    ///
    /// - Parameter path: The relative file path to add.
    /// - Returns: The `CommandResult` of the add command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func add(path: String) async throws -> CommandResult {
        let resolvedPath = Self.resolveChezmoiTargetPath(path)
        return try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["add", resolvedPath]
        )
    } // End of func add(path:)

    /// Applies remote changes from the source state to the local machine.
    ///
    /// - Returns: The `CommandResult` of the update command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func update() async throws -> CommandResult {
        return try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["update", "--no-tty"]
        )
    } // End of func update()

    /// Pulls remote changes into the chezmoi source state without applying them.
    ///
    /// Uses a fast-forward-only git pull in the chezmoi source repo by default.
    /// If branches have diverged, falls back to a non-rebase merge pull so the
    /// app can reconcile histories without forcing users into manual CLI steps.
    ///
    /// - Returns: The `CommandResult` of the pull command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func pullSource() async throws -> CommandResult {
        try await ensureAttachedHeadForSourceRepo()

        // Use a longer timeout than the ProcessRunner default because network/auth
        // round-trips can exceed 30s on some machines.
        let ffOnlyResult = try await runSourceGit(
            arguments: ["pull", "--no-rebase", "--ff-only", "--autostash"],
            timeout: 120,
            throwOnFailure: false
        )

        if ffOnlyResult.exitCode == 0 {
            return ffOnlyResult
        }

        // If histories diverged, fall back to merge pull (still non-rebase).
        // `--no-edit` prevents editor prompts in non-interactive app flows.
        if Self.isDivergedBranchPullError(ffOnlyResult.stderr) {
            let mergeResult = try await runSourceGit(
                arguments: ["pull", "--no-rebase", "--no-edit", "--autostash"],
                timeout: 120,
                throwOnFailure: false
            )
            if mergeResult.exitCode == 0 {
                return mergeResult
            }
            throw AppError.cliFailure(
                command: mergeResult.command,
                exitCode: mergeResult.exitCode,
                stderr: mergeResult.stderr
            )
        }

        throw AppError.cliFailure(
            command: ffOnlyResult.command,
            exitCode: ffOnlyResult.exitCode,
            stderr: ffOnlyResult.stderr
        )
    } // End of func pullSource()

    /// Returns true if stderr indicates pull failed due to branch divergence.
    ///
    /// Exposed internally for unit tests.
    static func isDivergedBranchPullError(_ stderr: String) -> Bool {
        let normalized = stderr.lowercased()
        return normalized.contains("diverging branches can't be fast-forwarded") ||
            normalized.contains("not possible to fast-forward, aborting")
    } // End of static func isDivergedBranchPullError(_:)

    /// Ensures the chezmoi source repo is on an attached local branch.
    ///
    /// If HEAD is detached, first preserves the current commit as a safety branch
    /// (`detached-backup-<short-sha>`) so it is not lost to garbage collection,
    /// then attempts to re-attach to the default remote branch (`origin/HEAD`)
    /// by switching to the matching local branch or creating it.
    /// - Throws: `AppError` if the repo cannot be re-attached safely.
    private func ensureAttachedHeadForSourceRepo() async throws {
        let headResult = try await runSourceGit(arguments: ["rev-parse", "--abbrev-ref", "HEAD"])
        let headRef = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard headRef == "HEAD" else { return }

        // Preserve detached HEAD commit as a safety branch before switching
        let shaResult = try await runSourceGit(
            arguments: ["rev-parse", "--short", "HEAD"],
            throwOnFailure: false
        )
        let shortSha = shaResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if shaResult.exitCode == 0, !shortSha.isEmpty {
            _ = try await runSourceGit(
                arguments: ["branch", "detached-backup-\(shortSha)", "HEAD"],
                throwOnFailure: false
            )
        }

        let remoteHeadResult = try await runSourceGit(
            arguments: ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
            throwOnFailure: false
        )
        let remoteHeadRef = remoteHeadResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        guard remoteHeadResult.exitCode == 0, remoteHeadRef.hasPrefix("origin/") else {
            throw AppError.unknown(
                "Detached HEAD in chezmoi source repo and origin/HEAD is unavailable. " +
                "Run: chezmoi git -- switch <branch> and set upstream before applying remote changes."
            )
        }

        let localBranch = String(remoteHeadRef.dropFirst("origin/".count))
        let switchExisting = try await runSourceGit(
            arguments: ["switch", localBranch],
            throwOnFailure: false
        )
        if switchExisting.exitCode == 0 { return }

        let switchCreateTracked = try await runSourceGit(
            arguments: ["switch", "-c", localBranch, "--track", remoteHeadRef],
            throwOnFailure: false
        )
        if switchCreateTracked.exitCode == 0 { return }

        throw AppError.unknown(
            """
            Detached HEAD in chezmoi source repo and auto-repair failed.
            Try:
              chezmoi git -- switch \(localBranch)
              chezmoi git -- branch --set-upstream-to=\(remoteHeadRef) \(localBranch)
            """
        )
    } // End of func ensureAttachedHeadForSourceRepo()

    /// Runs a git command inside the chezmoi source repo via `chezmoi git --`.
    private func runSourceGit(
        arguments: [String],
        timeout: TimeInterval = 30,
        throwOnFailure: Bool = true
    ) async throws -> CommandResult {
        return try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["git", "--"] + arguments,
            timeout: timeout,
            throwOnFailure: throwOnFailure
        )
    } // End of func runSourceGit(arguments:timeout:throwOnFailure:)

    /// Applies the chezmoi source state for a single file to the local machine.
    ///
    /// Does NOT pull from remote — call `pullSource()` first for remoteDrift files.
    ///
    /// - Parameter path: The relative file path to apply.
    /// - Returns: The `CommandResult` of the apply command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func apply(path: String) async throws -> CommandResult {
        let resolvedPath = Self.resolveChezmoiTargetPath(path)
        return try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["apply", "--no-tty", "--", resolvedPath]
        )
    } // End of func apply(path:)

    /// Stages, commits, and pushes all changes in the chezmoi source repo.
    ///
    /// Uses `chezmoi git` to run git commands in the correct source directory.
    /// Skips commit gracefully if there is nothing to commit.
    ///
    /// - Parameter message: The commit message.
    /// - Throws: `AppError` if staging or pushing fails.
    func commitAndPush(message: String) async throws {
        // Abort early if HEAD is detached — commits would be unreachable after push fails
        try await ensureAttachedHeadForSourceRepo()

        // Stage all changes
        _ = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["git", "--", "add", "."]
        )

        // Commit (exit code 1 = nothing to commit, which is fine)
        let commitResult = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["git", "--", "commit", "-m", message],
            throwOnFailure: false
        )

        // If nothing was committed, no need to push
        if commitResult.exitCode != 0 {
            if commitResult.stdout.contains("nothing to commit") ||
               commitResult.stderr.contains("nothing to commit") {
                return
            }
            throw AppError.cliFailure(
                command: commitResult.command,
                exitCode: commitResult.exitCode,
                stderr: commitResult.stderr
            )
        }

        // Push
        _ = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["git", "--", "push"]
        )
    } // End of func commitAndPush(message:)

    /// Returns the chezmoi source-state file path for a given target path.
    /// - Parameter path: The relative target file path (e.g., `.bashrc`).
    /// - Returns: The absolute path to the corresponding file in the chezmoi source directory.
    /// - Throws: `AppError` if the chezmoi command fails.
    func sourcePath(for path: String) async throws -> String {
        let resolvedPath = Self.resolveChezmoiTargetPath(path)
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["source-path", resolvedPath]
        )
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            throw AppError.parseFailure("chezmoi source-path returned empty output for \(path)")
        }
        return output
    } // End of func sourcePath(for:)

    /// Returns the set of all chezmoi-managed file paths (relative to home).
    ///
    /// Runs `chezmoi managed --include=files -p relative` and collects the output
    /// into a set of path strings.
    ///
    /// - Returns: A set of relative file paths managed by chezmoi.
    /// - Throws: `AppError` if the chezmoi command fails.
    func trackedFiles() async throws -> Set<String> {
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["managed", "--include=files", "-p", "relative"]
        )
        let paths = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(paths)
    } // End of func trackedFiles()

    /// Reads `git.autocommit` and `git.autopush` from `chezmoi dump-config`.
    ///
    /// - Returns: Parsed git automation config flags.
    /// - Throws: `AppError` if the command fails or the JSON cannot be parsed.
    func gitAutomationConfig() async throws -> GitAutomationConfig {
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["dump-config", "--format", "json"]
        )
        return try Self.parseGitAutomationConfig(result.stdout)
    } // End of func gitAutomationConfig()

    /// Parses `git.autocommit`/`git.autopush` from `chezmoi dump-config` JSON.
    ///
    /// Exposed as an internal static method to allow unit testing.
    /// - Parameter output: Raw JSON output from `chezmoi dump-config --format json`.
    /// - Returns: Parsed git automation flags.
    /// - Throws: `AppError.parseFailure` when required keys are missing or invalid.
    static func parseGitAutomationConfig(_ output: String) throws -> GitAutomationConfig {
        guard let data = output.data(using: .utf8) else {
            throw AppError.parseFailure("Invalid UTF-8 while parsing chezmoi dump-config output")
        }

        let rootAny = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = rootAny as? [String: Any] else {
            throw AppError.parseFailure("Expected top-level JSON object in chezmoi dump-config output")
        }

        guard let gitNode = root["git"] as? [String: Any] else {
            throw AppError.parseFailure("Missing 'git' section in chezmoi dump-config output")
        }

        guard let autoCommit = Self.parseBooleanConfigValue(gitNode["autocommit"]) else {
            throw AppError.parseFailure("Missing or invalid 'git.autocommit' in chezmoi dump-config output")
        }
        guard let autoPush = Self.parseBooleanConfigValue(gitNode["autopush"]) else {
            throw AppError.parseFailure("Missing or invalid 'git.autopush' in chezmoi dump-config output")
        }

        return GitAutomationConfig(
            autoCommit: autoCommit,
            autoPush: autoPush
        )
    } // End of static func parseGitAutomationConfig(_:)

    /// Converts a loosely typed config value into a Bool when possible.
    private static func parseBooleanConfigValue(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let text = value as? String {
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "on":
                return true
            case "false", "0", "no", "off":
                return false
            default:
                return nil
            }
        }
        return nil
    } // End of static func parseBooleanConfigValue(_:)

    /// Removes a file from chezmoi tracking (source state only; destination kept).
    ///
    /// The local file on disk is not deleted — only the chezmoi source-state entry
    /// is removed, so future sync operations will ignore this file.
    ///
    /// - Parameter path: The relative file path to forget.
    /// - Returns: The `CommandResult` of the forget command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func forget(path: String) async throws -> CommandResult {
        let resolvedPath = Self.resolveChezmoiTargetPath(path)
        return try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["forget", "--force", "--", resolvedPath]
        )
    } // End of func forget(path:)

    /// Normalizes a UI/status path into the format expected by chezmoi CLI path args.
    ///
    /// Accepted inputs:
    /// - Relative: `.zshrc` -> `~/.zshrc`
    /// - Dot-slash: `./.zshrc` -> `~/.zshrc`
    /// - Home-relative: `~/.zshrc` -> unchanged
    /// - Absolute: `/Users/me/.zshrc` -> unchanged
    ///
    /// Exposed internally for unit testing.
    static func resolveChezmoiTargetPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.hasPrefix("/") || trimmedPath.hasPrefix("~") {
            return trimmedPath
        }
        if trimmedPath.hasPrefix("./") {
            return "~/" + String(trimmedPath.dropFirst(2))
        }
        return "~/" + trimmedPath
    } // End of static func resolveChezmoiTargetPath(_:)
} // End of class ChezmoiService
