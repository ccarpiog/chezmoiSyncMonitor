import XCTest
@testable import ChezmoiSyncMonitor

/// Tests for the CLI service layer: ProcessRunner, PATHResolver, ChezmoiService parsers,
/// and GitService parsers.
final class ServiceTests: XCTestCase {

    // MARK: - ProcessRunner Tests

    /// Verifies that ProcessRunner can run a simple echo command successfully.
    func testProcessRunnerEcho() async throws {
        let result = try await ProcessRunner.run(
            command: "/bin/echo",
            arguments: ["hello"]
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello")
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.duration >= 0)
    } // End of func testProcessRunnerEcho()

    /// Verifies that ProcessRunner throws cliFailure on non-zero exit.
    func testProcessRunnerFailure() async {
        do {
            _ = try await ProcessRunner.run(
                command: "/bin/sh",
                arguments: ["-c", "exit 42"]
            )
            XCTFail("Expected cliFailure to be thrown")
        } catch let error as AppError {
            if case .cliFailure(_, let exitCode, _) = error {
                XCTAssertEqual(exitCode, 42)
            } else {
                XCTFail("Expected cliFailure, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    } // End of func testProcessRunnerFailure()

    /// Verifies that ProcessRunner throws on invalid command path.
    func testProcessRunnerInvalidCommand() async {
        do {
            _ = try await ProcessRunner.run(
                command: "/nonexistent/binary",
                arguments: []
            )
            XCTFail("Expected error to be thrown")
        } catch let error as AppError {
            if case .unknown(let message) = error {
                XCTAssertTrue(message.contains("Failed to launch"))
            } else {
                XCTFail("Expected unknown error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    } // End of func testProcessRunnerInvalidCommand()

    /// Verifies that ProcessRunner captures stderr output.
    func testProcessRunnerStderr() async {
        do {
            _ = try await ProcessRunner.run(
                command: "/bin/sh",
                arguments: ["-c", "echo error_msg >&2; exit 1"]
            )
            XCTFail("Expected cliFailure to be thrown")
        } catch let error as AppError {
            if case .cliFailure(_, _, let stderr) = error {
                XCTAssertTrue(stderr.contains("error_msg"))
            } else {
                XCTFail("Expected cliFailure, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    } // End of func testProcessRunnerStderr()

    // MARK: - PATHResolver Tests

    /// Verifies that PATHResolver can find standard system executables.
    func testPATHResolverFindsGit() {
        // git should be available on any macOS dev machine
        let path = PATHResolver.findExecutable("git")
        XCTAssertNotNil(path, "git should be findable")
        if let path = path {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    } // End of func testPATHResolverFindsGit()

    /// Verifies that PATHResolver returns nil for nonexistent executables.
    func testPATHResolverNonexistent() {
        let path = PATHResolver.findExecutable("definitely_nonexistent_binary_12345")
        XCTAssertNil(path)
    } // End of func testPATHResolverNonexistent()

    /// Verifies the git convenience method.
    func testPATHResolverGitConvenience() {
        let path = PATHResolver.gitPath()
        XCTAssertNotNil(path)
    }

    // MARK: - ChezmoiService Status Parser Tests

    /// Verifies parsing of a typical chezmoi status output with multiple files.
    /// Only entries with a non-space second column (apply-needed drift) are kept.
    func testParseStatusOutputMultipleFiles() {
        let output = """
         M .bashrc
        A  .config/new-tool/config.toml
        MM .zshrc
         D .old-config
        """

        let results = ChezmoiService.parseStatusOutput(output)
        XCTAssertEqual(results.count, 3)

        XCTAssertEqual(results[0].path, ".bashrc")
        XCTAssertEqual(results[0].state, .localDrift)
        XCTAssertEqual(results[1].path, ".zshrc")
        XCTAssertEqual(results[1].state, .localDrift)
        XCTAssertEqual(results[2].path, ".old-config")
        XCTAssertEqual(results[2].state, .localDrift)
    } // End of func testParseStatusOutputMultipleFiles()

    /// Verifies that empty output produces no FileStatus objects.
    func testParseStatusOutputEmpty() {
        let results = ChezmoiService.parseStatusOutput("")
        XCTAssertTrue(results.isEmpty)
    }

    /// Verifies that first-column-only status entries are ignored.
    func testParseStatusOutputSingleFile() {
        let output = "M  .already-added-file"
        let results = ChezmoiService.parseStatusOutput(output)
        XCTAssertTrue(results.isEmpty)
    }

    /// Verifies that available actions are correct for localDrift.
    func testParseStatusActionsLocalDrift() {
        let output = " M .bashrc"
        let results = ChezmoiService.parseStatusOutput(output)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].availableActions.contains(.viewDiff))
        XCTAssertTrue(results[0].availableActions.contains(.syncLocal))
    }

    /// Verifies that localDrift actions include openEditor.
    func testParseStatusActionsIncludeEditor() {
        let output = "MM .zshrc"
        let results = ChezmoiService.parseStatusOutput(output)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].availableActions.contains(.syncLocal))
        XCTAssertTrue(results[0].availableActions.contains(.openEditor))
        XCTAssertTrue(results[0].availableActions.contains(.viewDiff))
    } // End of func testParseStatusActionsIncludeEditor()

    /// Verifies that destination-missing entries are marked localMissing.
    func testParseStatusOutputMarksLocalMissing() {
        let output = " A .bin/tool"
        let results = ChezmoiService.parseStatusOutput(output)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, ".bin/tool")
        XCTAssertTrue(results[0].localMissing)
    } // End of func testParseStatusOutputMarksLocalMissing()

    // MARK: - Chezmoi path normalization tests

    /// Relative paths are converted to ~/path for chezmoi CLI commands.
    func testResolveChezmoiTargetPathRelative() {
        XCTAssertEqual(
            ChezmoiService.resolveChezmoiTargetPath(".config/nvim/init.lua"),
            "~/.config/nvim/init.lua"
        )
    }

    /// Paths already using ~/ are preserved as-is.
    func testResolveChezmoiTargetPathHomeRelative() {
        XCTAssertEqual(
            ChezmoiService.resolveChezmoiTargetPath("~/.zshrc"),
            "~/.zshrc"
        )
    }

    /// Absolute paths are preserved as-is.
    func testResolveChezmoiTargetPathAbsolute() {
        XCTAssertEqual(
            ChezmoiService.resolveChezmoiTargetPath("/Users/test/.zshrc"),
            "/Users/test/.zshrc"
        )
    }

    /// Leading ./ is removed and normalized to ~/path.
    func testResolveChezmoiTargetPathDotSlash() {
        XCTAssertEqual(
            ChezmoiService.resolveChezmoiTargetPath("./.config/karabiner/karabiner.json"),
            "~/.config/karabiner/karabiner.json"
        )
    }

    /// Verifies parsing of git.autocommit/autopush from dump-config JSON.
    func testParseGitAutomationConfig() throws {
        let output = """
        {
          "git": {
            "autocommit": true,
            "autopush": false
          }
        }
        """

        let config = try ChezmoiService.parseGitAutomationConfig(output)
        XCTAssertEqual(config.autoCommit, true)
        XCTAssertEqual(config.autoPush, false)
        XCTAssertFalse(config.isFullyEnabled)
    }

    /// Verifies invalid dump-config JSON fails with parseFailure.
    func testParseGitAutomationConfigInvalid() {
        let output = """
        {
          "git": {}
        }
        """

        XCTAssertThrowsError(try ChezmoiService.parseGitAutomationConfig(output)) { error in
            guard let appError = error as? AppError,
                  case .parseFailure = appError else {
                XCTFail("Expected parseFailure, got \(error)")
                return
            }
        }
    }

    // MARK: - GitService Ahead/Behind Parser Tests

    /// Verifies parsing of standard ahead/behind output.
    func testParseAheadBehindNormal() throws {
        let output = "3\t5"
        let result = try GitService.parseAheadBehind(output)
        XCTAssertEqual(result.ahead, 3)
        XCTAssertEqual(result.behind, 5)
    }

    /// Verifies parsing when local and remote are in sync.
    func testParseAheadBehindZeros() throws {
        let output = "0\t0"
        let result = try GitService.parseAheadBehind(output)
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    /// Verifies parsing handles trailing whitespace/newlines.
    func testParseAheadBehindWithWhitespace() throws {
        let output = "  1\t2  \n"
        let result = try GitService.parseAheadBehind(output)
        XCTAssertEqual(result.ahead, 1)
        XCTAssertEqual(result.behind, 2)
    }

    /// Verifies that malformed output throws a parse error.
    func testParseAheadBehindInvalid() {
        XCTAssertThrowsError(try GitService.parseAheadBehind("not valid")) { error in
            if let appError = error as? AppError,
               case .parseFailure = appError {
                // Expected
            } else {
                XCTFail("Expected parseFailure, got \(error)")
            }
        }
    } // End of func testParseAheadBehindInvalid()

    /// Verifies that single-value output throws a parse error.
    func testParseAheadBehindSingleValue() {
        XCTAssertThrowsError(try GitService.parseAheadBehind("5")) { error in
            if let appError = error as? AppError,
               case .parseFailure = appError {
                // Expected
            } else {
                XCTFail("Expected parseFailure, got \(error)")
            }
        }
    }

    /// Verifies detached HEAD stderr is treated as missing upstream.
    func testIsMissingUpstreamErrorDetachedHead() {
        XCTAssertTrue(
            GitService.isMissingUpstreamError("fatal: HEAD does not point to a branch")
        )
    }

    /// Verifies no-upstream stderr is treated as missing upstream.
    func testIsMissingUpstreamErrorNoUpstreamConfigured() {
        XCTAssertTrue(
            GitService.isMissingUpstreamError("fatal: no upstream configured for branch 'main'")
        )
    }

    /// Verifies unrelated stderr is not treated as missing upstream.
    func testIsMissingUpstreamErrorFalseForOtherFailures() {
        XCTAssertFalse(
            GitService.isMissingUpstreamError("fatal: bad revision 'HEAD~999'")
        )
    }

    /// Verifies fetch-without-remote stderr is treated as non-fatal.
    func testIsNoRemoteConfiguredError() {
        XCTAssertTrue(
            GitService.isNoRemoteConfiguredError("fatal: No remote repository specified.")
        )
    }

    /// Verifies diverged-branch stderr is detected for pull fallback.
    func testIsDivergedBranchPullError() {
        XCTAssertTrue(
            ChezmoiService.isDivergedBranchPullError(
                "fatal: Not possible to fast-forward, aborting."
            )
        )
        XCTAssertTrue(
            ChezmoiService.isDivergedBranchPullError(
                "hint: Diverging branches can't be fast-forwarded"
            )
        )
    }

    /// Verifies unrelated stderr does not trigger diverged-branch fallback.
    func testIsDivergedBranchPullErrorFalse() {
        XCTAssertFalse(
            ChezmoiService.isDivergedBranchPullError(
                "fatal: could not read from remote repository"
            )
        )
    }
} // End of class ServiceTests
