import XCTest
@testable import ChezmoiSyncMonitor

/// Table-driven tests for FileStateEngine covering all state combinations
/// and action set verification.
final class FileStateEngineTests: XCTestCase {

    private var engine: FileStateEngine!

    override func setUp() {
        super.setUp()
        engine = FileStateEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Classification Tests

    /// All clean: no local files, no remote changes → empty result.
    func testAllCleanNoFiles() {
        let result = engine.classify(
            localFiles: [],
            remoteBehind: 0,
            remoteChangedFiles: []
        )
        XCTAssertTrue(result.isEmpty)
    } // End of func testAllCleanNoFiles()

    /// Empty inputs: no local files, zero behind, empty remote set.
    func testEmptyInputs() {
        let result = engine.classify(
            localFiles: [],
            remoteBehind: 0,
            remoteChangedFiles: Set<String>()
        )
        XCTAssertTrue(result.isEmpty)
    }

    /// Local drift only: file appears in chezmoi status but not in remote changes.
    func testLocalDriftOnly() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift, availableActions: [.viewDiff, .syncLocal])
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 0,
            remoteChangedFiles: []
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].path, ".bashrc")
        XCTAssertEqual(result[0].state, .localDrift)
    } // End of func testLocalDriftOnly()

    /// Remote drift only: file not in chezmoi status but in remote changes.
    func testRemoteDriftOnly() {
        let result = engine.classify(
            localFiles: [],
            remoteBehind: 2,
            remoteChangedFiles: [".zshrc"]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].path, ".zshrc")
        XCTAssertEqual(result[0].state, .remoteDrift)
    } // End of func testRemoteDriftOnly()

    /// Dual drift: file appears in both chezmoi status and remote changes.
    func testDualDrift() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift, availableActions: [.viewDiff, .syncLocal])
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: [".bashrc"]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].path, ".bashrc")
        XCTAssertEqual(result[0].state, .dualDrift)
    } // End of func testDualDrift()

    /// Mixed scenario: some local-only, some remote-only, some dual drift.
    func testMixedScenario() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".vimrc", state: .localDrift),
            FileStatus(path: ".gitconfig", state: .localDrift),
        ]
        let remoteChanged: Set<String> = [".vimrc", ".zshrc", ".tmux.conf"]

        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 3,
            remoteChangedFiles: remoteChanged
        )

        // Should have 5 files total:
        // .bashrc → localDrift (local only)
        // .vimrc → dualDrift (both)
        // .gitconfig → localDrift (local only)
        // .tmux.conf → remoteDrift (remote only)
        // .zshrc → remoteDrift (remote only)
        XCTAssertEqual(result.count, 5)

        let byPath = Dictionary(uniqueKeysWithValues: result.map { ($0.path, $0) })

        XCTAssertEqual(byPath[".bashrc"]?.state, .localDrift)
        XCTAssertEqual(byPath[".vimrc"]?.state, .dualDrift)
        XCTAssertEqual(byPath[".gitconfig"]?.state, .localDrift)
        XCTAssertEqual(byPath[".zshrc"]?.state, .remoteDrift)
        XCTAssertEqual(byPath[".tmux.conf"]?.state, .remoteDrift)
    } // End of func testMixedScenario()

    /// Error state files are preserved without reclassification.
    func testErrorStatePreserved() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .error, errorMessage: "parse failed")
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: [".bashrc"]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .error)
        XCTAssertEqual(result[0].errorMessage, "parse failed")
    } // End of func testErrorStatePreserved()

    /// The simplified classify method (without remoteChangedFiles) preserves local drift.
    func testSimplifiedClassifyFallback() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift)
        ]
        let result = engine.classify(localFiles: localFiles, remoteBehind: 5)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .localDrift)
    }

    // MARK: - Action Set Verification

    /// Clean state actions: forgetFile only (no diff — files are identical).
    func testActionsForClean() {
        let actions = FileStateEngine.actions(for: .clean)
        XCTAssertEqual(actions, [.forgetFile])
    }

    /// Local drift actions: syncLocal, revertLocal, viewDiff, openEditor, forgetFile.
    func testActionsForLocalDrift() {
        let actions = FileStateEngine.actions(for: .localDrift)
        XCTAssertTrue(actions.contains(.syncLocal))
        XCTAssertTrue(actions.contains(.revertLocal))
        XCTAssertTrue(actions.contains(.viewDiff))
        XCTAssertTrue(actions.contains(.openEditor))
        XCTAssertTrue(actions.contains(.forgetFile))
        XCTAssertEqual(actions.count, 5)
    }

    /// Remote drift actions: syncLocal, applyRemote, viewDiff, forgetFile.
    func testActionsForRemoteDrift() {
        let actions = FileStateEngine.actions(for: .remoteDrift)
        XCTAssertTrue(actions.contains(.syncLocal))
        XCTAssertTrue(actions.contains(.applyRemote))
        XCTAssertTrue(actions.contains(.viewDiff))
        XCTAssertTrue(actions.contains(.forgetFile))
        XCTAssertEqual(actions.count, 4)
    }

    /// Dual drift actions: viewDiff, openEditor, openMergeTool, forgetFile (no syncLocal/applyRemote per PRD conflict-risk).
    func testActionsForDualDrift() {
        let actions = FileStateEngine.actions(for: .dualDrift)
        XCTAssertTrue(actions.contains(.viewDiff))
        XCTAssertTrue(actions.contains(.openEditor))
        XCTAssertTrue(actions.contains(.openMergeTool))
        XCTAssertTrue(actions.contains(.forgetFile))
        XCTAssertFalse(actions.contains(.syncLocal))
        XCTAssertFalse(actions.contains(.applyRemote))
        XCTAssertEqual(actions.count, 4)
    } // End of func testActionsForDualDrift()

    /// Error state actions: viewDiff only.
    func testActionsForError() {
        let actions = FileStateEngine.actions(for: .error)
        XCTAssertEqual(actions, [.viewDiff])
    }

    /// Verifies that classified files get the correct actions assigned.
    func testClassifiedFilesHaveCorrectActions() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".vimrc", state: .localDrift),
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: [".vimrc", ".zshrc"]
        )

        let byPath = Dictionary(uniqueKeysWithValues: result.map { ($0.path, $0) })

        // .bashrc is localDrift
        XCTAssertEqual(byPath[".bashrc"]?.availableActions, [.syncLocal, .revertLocal, .viewDiff, .openEditor, .forgetFile])

        // .vimrc is dualDrift (conflict-risk: no syncLocal/applyRemote per PRD)
        XCTAssertEqual(
            byPath[".vimrc"]?.availableActions,
            [.viewDiff, .openEditor, .openMergeTool, .forgetFile]
        )

        // .zshrc is remoteDrift (syncLocal = Keep Local, applyRemote = Keep Remote)
        XCTAssertEqual(byPath[".zshrc"]?.availableActions, [.syncLocal, .applyRemote, .viewDiff, .forgetFile])
    } // End of func testClassifiedFilesHaveCorrectActions()

    // MARK: - GitService Remote Changed Files Parser Tests

    /// Verifies parsing of git diff --name-only output.
    func testParseRemoteChangedFiles() {
        let output = """
        dot_bashrc
        dot_zshrc
        dot_config/nvim/init.lua
        """
        let result = GitService.parseRemoteChangedFiles(output)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains("dot_bashrc"))
        XCTAssertTrue(result.contains("dot_zshrc"))
        XCTAssertTrue(result.contains("dot_config/nvim/init.lua"))
    } // End of func testParseRemoteChangedFiles()

    /// Verifies that empty output produces an empty set.
    func testParseRemoteChangedFilesEmpty() {
        let result = GitService.parseRemoteChangedFiles("")
        XCTAssertTrue(result.isEmpty)
    }

    /// Verifies that whitespace-only output produces an empty set.
    func testParseRemoteChangedFilesWhitespaceOnly() {
        let result = GitService.parseRemoteChangedFiles("  \n  \n  ")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Path Normalization Tests

    /// Verifies chezmoi source path normalization (dot_ prefix).
    func testNormalizeSourcePathDotPrefix() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("dot_bashrc"), ".bashrc")
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("dot_config/nvim/init.lua"), ".config/nvim/init.lua")
    }

    /// Verifies normalization of private_ and other chezmoi prefixes.
    func testNormalizeSourcePathMultiplePrefixes() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("private_dot_ssh/config"), ".ssh/config")
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("executable_dot_local/bin/script"), ".local/bin/script")
    }

    /// Verifies .tmpl suffix removal.
    func testNormalizeSourcePathTmplSuffix() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("dot_gitconfig.tmpl"), ".gitconfig")
    }

    /// Verifies classification works with source-style remote paths (dot_ prefix).
    func testClassifyWithSourceStyleRemotePaths() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift)
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: ["dot_bashrc"]
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .dualDrift)
    } // End of func testClassifyWithSourceStyleRemotePaths()

    /// Verifies remote-only files with source-style paths get normalized.
    func testRemoteOnlyWithSourceStylePaths() {
        let result = engine.classify(
            localFiles: [],
            remoteBehind: 1,
            remoteChangedFiles: ["dot_zshrc"]
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].path, ".zshrc")
        XCTAssertEqual(result[0].state, .remoteDrift)
    }

    /// Verifies lastModified is preserved through classification.
    func testLastModifiedPreserved() {
        let date = Date()
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift, lastModified: date)
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: [".bashrc"]
        )

        XCTAssertEqual(result[0].lastModified, date)
    }
    // MARK: - Tracked Files Classification Tests

    /// Tracked files not in drift appear as clean in the classify output.
    func testTrackedFilesAppearAsClean() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
        ]
        let trackedFiles: Set<String> = [".bashrc", ".zshrc", ".vimrc"]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 0,
            remoteChangedFiles: [],
            trackedFiles: trackedFiles
        )

        let byPath = Dictionary(uniqueKeysWithValues: result.map { ($0.path, $0) })

        // .bashrc has local drift
        XCTAssertEqual(byPath[".bashrc"]?.state, .localDrift)
        // .zshrc and .vimrc are clean tracked files
        XCTAssertEqual(byPath[".zshrc"]?.state, .clean)
        XCTAssertEqual(byPath[".vimrc"]?.state, .clean)
        // Clean files have forgetFile action
        XCTAssertTrue(byPath[".zshrc"]?.availableActions.contains(.forgetFile) ?? false)
    } // End of func testTrackedFilesAppearAsClean()

    /// Non-tracked paths are excluded from classify output.
    func testNonTrackedPathsExcluded() {
        let localFiles: [FileStatus] = []
        let trackedFiles: Set<String> = [".bashrc"]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 0,
            remoteChangedFiles: [],
            trackedFiles: trackedFiles
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.path, ".bashrc")
        XCTAssertEqual(result.first?.state, .clean)
    } // End of func testNonTrackedPathsExcluded()

    /// Tracked + local drift = localDrift; tracked + remote drift = remoteDrift; tracked + both = dualDrift.
    func testTrackedFilesClassificationMatrix() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".vimrc", state: .localDrift),
        ]
        let trackedFiles: Set<String> = [".bashrc", ".vimrc", ".zshrc", ".profile"]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 1,
            remoteChangedFiles: [".vimrc", ".zshrc"],
            trackedFiles: trackedFiles
        )

        let byPath = Dictionary(uniqueKeysWithValues: result.map { ($0.path, $0) })

        XCTAssertEqual(byPath[".bashrc"]?.state, .localDrift)   // tracked + local only
        XCTAssertEqual(byPath[".vimrc"]?.state, .dualDrift)     // tracked + local + remote
        XCTAssertEqual(byPath[".zshrc"]?.state, .remoteDrift)   // tracked + remote only
        XCTAssertEqual(byPath[".profile"]?.state, .clean)       // tracked + no drift
    } // End of func testTrackedFilesClassificationMatrix()

    /// Empty tracked files set = existing drift-only behavior.
    func testEmptyTrackedFilesFallback() {
        let localFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
        ]
        let result = engine.classify(
            localFiles: localFiles,
            remoteBehind: 0,
            remoteChangedFiles: [],
            trackedFiles: []
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.state, .localDrift)
    } // End of func testEmptyTrackedFilesFallback()
} // End of class FileStateEngineTests
