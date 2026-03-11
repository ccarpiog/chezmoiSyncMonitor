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

            var actions: [FileAction] = [.viewDiff]
            if state == .localDrift {
                actions.append(.syncLocal)
                actions.append(.openEditor)
            }

            results.append(FileStatus(
                path: path,
                state: state,
                availableActions: actions
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
    /// Uses a fast-forward-only git pull in the chezmoi source repo to avoid
    /// rebase-based detached-HEAD states if the process is interrupted.
    ///
    /// - Returns: The `CommandResult` of the pull command.
    /// - Throws: `AppError` if the chezmoi command fails.
    func pullSource() async throws -> CommandResult {
        try await ensureAttachedHeadForSourceRepo()

        // Use a longer timeout than the ProcessRunner default because network/auth
        // round-trips can exceed 30s on some machines.
        let result = try await runSourceGit(
            arguments: ["pull", "--no-rebase", "--ff-only", "--autostash"],
            timeout: 120,
            throwOnFailure: false
        )

        if result.exitCode != 0 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result
    } // End of func pullSource()

    /// Ensures the chezmoi source repo is on an attached local branch.
    ///
    /// If HEAD is detached, attempts to re-attach to the default remote branch
    /// (`origin/HEAD`) by switching to the matching local branch or creating it.
    /// - Throws: `AppError` if the repo cannot be re-attached safely.
    private func ensureAttachedHeadForSourceRepo() async throws {
        let headResult = try await runSourceGit(arguments: ["rev-parse", "--abbrev-ref", "HEAD"])
        let headRef = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard headRef == "HEAD" else { return }

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
