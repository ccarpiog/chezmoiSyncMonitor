import Foundation

/// Engine that classifies per-file sync states by combining chezmoi local status
/// with git remote information.
///
/// The classification truth table:
/// - No local drift, no remote drift → `clean`
/// - Local drift only → `localDrift`
/// - Remote drift only → `remoteDrift`
/// - Both local and remote drift → `dualDrift`
///
/// Files already in `error` state are preserved as-is.
final class FileStateEngine: FileStateEngineProtocol, Sendable {

    /// Converts a chezmoi source-repo file path to a destination-style path.
    ///
    /// Chezmoi source repos use naming conventions like `dot_bashrc` for `.bashrc`,
    /// `private_dot_ssh` for `.ssh`, etc. Git diff returns these source-style paths.
    /// This method normalizes them for comparison with chezmoi status output.
    ///
    /// - Parameter sourcePath: A path from the chezmoi source repo (e.g., `dot_bashrc`).
    /// - Returns: The normalized destination-style path (e.g., `.bashrc`).
    static func normalizeSourcePath(_ sourcePath: String) -> String {
        var components = sourcePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        for i in 0..<components.count {
            var part = components[i]
            // Remove chezmoi attribute prefixes (may be stacked, e.g., private_executable_dot_)
            let prefixes = ["private_", "readonly_", "exact_", "empty_", "executable_"]
            var changed = true
            while changed {
                changed = false
                for prefix in prefixes {
                    if part.hasPrefix(prefix) {
                        part = String(part.dropFirst(prefix.count))
                        changed = true
                    }
                }
            } // End of loop removing attribute prefixes
            // Replace dot_ with .
            if part.hasPrefix("dot_") {
                part = "." + String(part.dropFirst(4))
            }
            // Remove .tmpl suffix
            if part.hasSuffix(".tmpl") {
                part = String(part.dropLast(5))
            }
            components[i] = part
        } // End of loop normalizing path components
        return components.joined(separator: "/")
    } // End of static func normalizeSourcePath(_:)

    /// Classifies file statuses using only the remote behind count.
    ///
    /// This is a simplified overload that treats all files as potentially
    /// remote-drifted when `remoteBehind > 0`, but without per-file granularity.
    /// Prefer the overload that accepts `remoteChangedFiles` for accurate results.
    ///
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi.
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    /// - Returns: Updated file statuses with classified sync states.
    func classify(localFiles: [FileStatus], remoteBehind: Int) -> [FileStatus] {
        // Without per-file remote info, we can only return localFiles as-is
        // since we don't know which specific files changed remotely
        return classify(localFiles: localFiles, remoteBehind: remoteBehind, remoteChangedFiles: [])
    } // End of func classify(localFiles:remoteBehind:)

    /// Classifies file statuses by combining local chezmoi status with remote
    /// change information for per-file granularity.
    ///
    /// Files present in chezmoi status have local drift. Files present in
    /// `remoteChangedFiles` have remote drift. Files in both have dual drift.
    /// Files already in error state retain that state.
    ///
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi (all currently marked `localDrift`).
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    ///   - remoteChangedFiles: The set of file paths that changed in remote commits.
    /// - Returns: Updated file statuses with classified sync states and actions.
    func classify(localFiles: [FileStatus], remoteBehind: Int, remoteChangedFiles: Set<String>) -> [FileStatus] {
        return classify(localFiles: localFiles, remoteBehind: remoteBehind, remoteChangedFiles: remoteChangedFiles, trackedFiles: [])
    } // End of func classify(localFiles:remoteBehind:remoteChangedFiles:)

    /// Classifies file statuses by combining local chezmoi status, remote change
    /// information, and the full set of tracked files for per-file granularity.
    ///
    /// Files present in chezmoi status have local drift. Files present in
    /// `remoteChangedFiles` have remote drift. Files in both have dual drift.
    /// Tracked files not in either set are added as `clean`.
    /// Files already in error state retain that state.
    /// Results are sorted by path for stable ordering.
    ///
    /// - Parameters:
    ///   - localFiles: The file statuses from chezmoi (all currently marked `localDrift`).
    ///   - remoteBehind: How many commits the local branch is behind the remote.
    ///   - remoteChangedFiles: The set of file paths that changed in remote commits.
    ///   - trackedFiles: The full set of chezmoi-managed file paths.
    /// - Returns: Updated file statuses with classified sync states and actions, including clean files.
    func classify(localFiles: [FileStatus], remoteBehind: Int, remoteChangedFiles: Set<String>, trackedFiles: Set<String>) -> [FileStatus] {
        let localPaths = Set(localFiles.map(\.path))

        // Normalize remote source-repo paths to destination-style paths for comparison
        let normalizedRemotePaths = Set(remoteChangedFiles.map { FileStateEngine.normalizeSourcePath($0) })

        // Determine which remote files also have local drift
        let remoteOnlyFiles = normalizedRemotePaths.subtracting(localPaths)

        var result: [FileStatus] = []

        // Process local files: they might be localDrift or dualDrift
        for file in localFiles {
            if file.state == .error {
                // Preserve error state
                result.append(file)
                continue
            }

            let hasRemoteDrift = normalizedRemotePaths.contains(file.path)
            let newState: FileSyncState = hasRemoteDrift ? .dualDrift : .localDrift
            result.append(FileStatus(
                path: file.path,
                state: newState,
                lastModified: file.lastModified,
                availableActions: FileStateEngine.actions(for: newState, localMissing: file.localMissing),
                errorMessage: file.errorMessage,
                localMissing: file.localMissing
            ))
        } // End of loop processing local files

        // Add remote-only files as remoteDrift
        for path in remoteOnlyFiles.sorted() {
            // A remote-only file not yet in trackedFiles is new (no local copy exists).
            // Only infer localMissing when trackedFiles is non-empty; when tracked file
            // discovery fails, the set degrades to empty and every file would be
            // incorrectly flagged as missing.
            let isNewRemoteFile = !trackedFiles.isEmpty && !trackedFiles.contains(path)
            result.append(FileStatus(
                path: path,
                state: .remoteDrift,
                availableActions: FileStateEngine.actions(for: .remoteDrift, localMissing: isNewRemoteFile),
                localMissing: isNewRemoteFile
            ))
        } // End of loop processing remote-only files

        // Add tracked files that have no drift as clean entries
        let classifiedPaths = Set(result.map(\.path))
        for path in trackedFiles.sorted() where !classifiedPaths.contains(path) {
            result.append(FileStatus(
                path: path,
                state: .clean,
                availableActions: FileStateEngine.actions(for: .clean)
            ))
        } // End of loop adding clean tracked files

        // Sort by path for stable ordering
        return result.sorted { $0.path < $1.path }
    } // End of func classify(localFiles:remoteBehind:remoteChangedFiles:trackedFiles:)

    /// Returns the set of available actions for a given sync state.
    ///
    /// Action derivation per state:
    /// - `clean`: `forgetFile`
    /// - `localDrift`: `syncLocal`, `revertLocal`, `viewDiff`, `openEditor`, `forgetFile`
    /// - `remoteDrift`: `syncLocal`, `applyRemote`, `viewDiff`, `forgetFile`
    /// - `dualDrift`: `viewDiff`, `openEditor`, `openMergeTool`, `forgetFile`
    /// - `error`: `viewDiff`
    ///
    /// - Parameter state: The file sync state.
    /// - Returns: An array of actions available for that state.
    static func actions(for state: FileSyncState) -> [FileAction] {
        return actions(for: state, localMissing: false)
    } // End of static func actions(for:)

    /// Returns the set of available actions for a given sync state, adjusted
    /// when the local file is missing from disk.
    ///
    /// When `localMissing` is true:
    /// - `viewDiff` is removed (no local file to diff against)
    /// - `openEditor` is removed (no local file to edit)
    /// - `openMergeTool` is removed (nothing to merge with)
    /// - `applyRemote` is added so the user can create the file from the tracked version
    ///
    /// - Parameters:
    ///   - state: The file sync state.
    ///   - localMissing: Whether the local destination file does not exist on disk.
    /// - Returns: An array of actions available for that state.
    static func actions(for state: FileSyncState, localMissing: Bool) -> [FileAction] {
        let base: [FileAction]
        switch state {
        case .clean:
            base = [.forgetFile]
        case .localDrift:
            base = [.syncLocal, .revertLocal, .viewDiff, .openEditor, .forgetFile]
        case .remoteDrift:
            base = [.syncLocal, .applyRemote, .viewDiff, .forgetFile]
        case .dualDrift:
            base = [.viewDiff, .openEditor, .openMergeTool, .forgetFile]
        case .error:
            base = [.viewDiff]
        } // End of switch state

        guard localMissing else { return base }

        // When local file is missing:
        // - remove Edit/Merge (no local file to open)
        // - remove syncLocal/revertLocal (chezmoi add/apply fails on missing source target)
        // - add applyRemote so the user can create the file from the tracked version
        var adjusted = base.filter {
            $0 != .openEditor && $0 != .openMergeTool && $0 != .syncLocal && $0 != .revertLocal && $0 != .viewDiff
        }
        if !adjusted.contains(.applyRemote) {
            adjusted.insert(.applyRemote, at: 0)
        }
        return adjusted
    } // End of static func actions(for:localMissing:)
} // End of class FileStateEngine
