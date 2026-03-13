import Foundation

/// Implementation of `GitServiceProtocol` that wraps git CLI commands.
///
/// Operates on the chezmoi source directory, which is determined by
/// running `chezmoi source-path`.
final class GitService: GitServiceProtocol, Sendable {

    /// The resolved path to the git executable.
    private let gitBinary: String

    /// The resolved path to the chezmoi executable (needed for source-path lookup).
    private let chezmoiBinary: String

    /// Creates a new GitService.
    ///
    /// - Parameters:
    ///   - gitPath: An optional explicit path to the git binary.
    ///   - chezmoiPath: An optional explicit path to the chezmoi binary.
    /// - Throws: `AppError.unknown` if either binary cannot be found.
    init(gitPath: String? = nil, chezmoiPath: String? = nil) throws {
        if let path = gitPath {
            self.gitBinary = path
        } else {
            guard let resolved = PATHResolver.gitPath() else {
                throw AppError.unknown("git binary not found in PATH")
            }
            self.gitBinary = resolved
        }

        if let path = chezmoiPath {
            self.chezmoiBinary = path
        } else {
            guard let resolved = PATHResolver.chezmoiPath() else {
                throw AppError.unknown("chezmoi binary not found in PATH")
            }
            self.chezmoiBinary = resolved
        }
    } // End of init(gitPath:chezmoiPath:)

    /// Resolves the chezmoi source directory by running `chezmoi source-path`.
    ///
    /// - Returns: The absolute path to the chezmoi source directory.
    /// - Throws: `AppError` if the command fails or returns empty output.
    private func sourceDirectory() async throws -> String {
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["source-path"]
        )
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw AppError.parseFailure("chezmoi source-path returned empty output")
        }
        return path
    } // End of func sourceDirectory()

    /// Fetches the latest refs from the remote repository.
    ///
    /// - Returns: The `CommandResult` of the fetch command.
    /// - Throws: `AppError` if the git command fails.
    func fetch() async throws -> CommandResult {
        let sourceDir = try await sourceDirectory()
        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "fetch"],
            throwOnFailure: false
        )

        if result.exitCode == 0 || GitService.isNoRemoteConfiguredError(result.stderr) {
            return result
        }

        throw AppError.cliFailure(
            command: result.command,
            exitCode: result.exitCode,
            stderr: result.stderr
        )
    } // End of func fetch()

    /// Returns how many commits the local branch is ahead of and behind the remote.
    ///
    /// Runs `git rev-list --left-right --count HEAD...@{upstream}` and parses
    /// the tab-separated output.
    ///
    /// - Returns: A tuple with `ahead` and `behind` commit counts.
    /// - Throws: `AppError` if the git command fails or output cannot be parsed.
    func aheadBehind() async throws -> (ahead: Int, behind: Int) {
        let sourceDir = try await sourceDirectory()
        guard let upstreamRef = try await upstreamRef(in: sourceDir) else {
            return (ahead: 0, behind: 0)
        }

        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "rev-list", "--left-right", "--count", "HEAD...\(upstreamRef)"]
        )
        return try GitService.parseAheadBehind(result.stdout)
    } // End of func aheadBehind()

    /// Returns the set of file paths that changed in commits the local branch is behind on.
    ///
    /// Runs `git diff --name-only HEAD...@{upstream}` to find files that differ
    /// between the current HEAD and the upstream tracking branch.
    ///
    /// - Returns: A set of relative file paths that changed remotely.
    /// - Throws: `AppError` if the git command fails.
    func remoteChangedFiles() async throws -> Set<String> {
        let sourceDir = try await sourceDirectory()
        guard let upstreamRef = try await upstreamRef(in: sourceDir) else {
            return []
        }

        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "diff", "--name-only", "HEAD...\(upstreamRef)"],
            throwOnFailure: false
        )

        if result.exitCode != 0 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return GitService.parseRemoteChangedFiles(result.stdout)
    } // End of func remoteChangedFiles()

    /// Returns the unified diff of a specific source file between HEAD and upstream.
    ///
    /// Computes the relative path of the file within the source directory so the
    /// git diff command can target it precisely.
    ///
    /// - Parameter sourcePath: The absolute path to the file in the chezmoi source directory.
    /// - Returns: The diff output, or an empty string if there are no remote changes.
    /// - Throws: `AppError` if the git command fails.
    func remoteFileDiff(for sourcePath: String) async throws -> String {
        let sourceDir = try await sourceDirectory()
        guard let upstreamRef = try await upstreamRef(in: sourceDir) else {
            return ""
        }

        // Compute relative path within the source repo
        let relativePath: String
        if sourcePath.hasPrefix(sourceDir + "/") {
            relativePath = String(sourcePath.dropFirst(sourceDir.count + 1))
        } else {
            relativePath = sourcePath
        }

        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "diff", "HEAD...\(upstreamRef)", "--", relativePath],
            throwOnFailure: false
        )

        if result.exitCode != 0 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result.stdout
    } // End of func remoteFileDiff(for:)

    /// Parses the output of `git diff --name-only` into a set of file paths.
    ///
    /// Exposed as an internal static method to allow unit testing without
    /// running the actual git binary.
    ///
    /// - Parameter output: The raw stdout from `git diff --name-only`.
    /// - Returns: A set of non-empty file paths.
    static func parseRemoteChangedFiles(_ output: String) -> Set<String> {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(lines)
    } // End of static func parseRemoteChangedFiles(_:)

    /// Resolves the upstream tracking ref for the current HEAD branch.
    ///
    /// Returns `nil` for non-fatal states like detached HEAD or no upstream configured.
    /// Throws for other git failures.
    private func upstreamRef(in sourceDir: String) async throws -> String? {
        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            throwOnFailure: false
        )

        if result.exitCode == 0 {
            let ref = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return ref.isEmpty ? nil : ref
        }

        if GitService.isMissingUpstreamError(result.stderr) {
            return nil
        }

        throw AppError.cliFailure(
            command: result.command,
            exitCode: result.exitCode,
            stderr: result.stderr
        )
    } // End of func upstreamRef(in:)

    /// Returns true if stderr indicates there is no usable upstream branch.
    ///
    /// Exposed internally for unit tests.
    static func isMissingUpstreamError(_ stderr: String) -> Bool {
        let normalized = stderr.lowercased()
        return normalized.contains("head does not point to a branch") ||
            normalized.contains("no upstream configured") ||
            normalized.contains("no upstream branch") ||
            normalized.contains("fatal: @{upstream}") ||
            normalized.contains("upstream branch of your current branch")
    } // End of static func isMissingUpstreamError(_:)

    /// Returns true if stderr indicates no remote is configured for fetch.
    ///
    /// Exposed internally for unit tests.
    static func isNoRemoteConfiguredError(_ stderr: String) -> Bool {
        let normalized = stderr.lowercased()
        return normalized.contains("no remote repository specified") ||
            normalized.contains("no such remote") ||
            normalized.contains("does not appear to be a git repository")
    } // End of static func isNoRemoteConfiguredError(_:)

    /// Parses the `git rev-list --left-right --count` output into ahead/behind counts.
    ///
    /// Exposed as an internal static method to allow unit testing without
    /// running the actual git binary.
    ///
    /// - Parameter output: The raw stdout, expected format: `"N\tM"`.
    /// - Returns: A tuple with `ahead` and `behind` counts.
    /// - Throws: `AppError.parseFailure` if the output format is unexpected.
    static func parseAheadBehind(_ output: String) throws -> (ahead: Int, behind: Int) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: "\t")

        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else {
            throw AppError.parseFailure("Expected 'N\\tM' format from git rev-list, got: '\(trimmed)'")
        }

        return (ahead: ahead, behind: behind)
    } // End of static func parseAheadBehind(_:)
} // End of class GitService
