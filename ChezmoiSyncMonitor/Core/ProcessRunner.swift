import Foundation
import os

/// A utility for running external CLI commands asynchronously.
///
/// Uses `Process` and `Pipe` for stdout/stderr capture, measures
/// execution duration, and supports timeout-based termination.
/// Checks for Swift Task cancellation before launching processes.
enum ProcessRunner: Sendable {

    /// Runs an external command and captures its output.
    ///
    /// - Parameters:
    ///   - command: The path to the executable (e.g., `/usr/bin/git`).
    ///   - arguments: The arguments to pass to the executable.
    ///   - timeout: Maximum wall-clock seconds before the process is terminated. Defaults to 30.
    ///   - throwOnFailure: If `true`, throws `AppError.cliFailure` on non-zero exit. Defaults to `true`.
    /// - Returns: A `CommandResult` with exit code, stdout, stderr, and duration.
    /// - Throws: `CancellationError` if the current Task is cancelled before launch,
    ///           `AppError.cliFailure` if `throwOnFailure` is `true` and the process exits with a non-zero code,
    ///           `AppError.unknown` if the process cannot be launched or times out.
    static func run(
        command: String,
        arguments: [String] = [],
        timeout: TimeInterval = 30,
        throwOnFailure: Bool = true
    ) async throws -> CommandResult {
        // Check for Task cancellation before starting the process
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        // Prevent commands from blocking on stdin in this non-interactive app.
        // Without this, any command that tries to read input (git credential
        // prompts, editor invocations, chezmoi confirmations) would hang.
        process.standardInput = FileHandle.nullDevice

        // Suppress interactive git prompts (credentials, editors) so they
        // fail fast instead of hanging in a non-TTY context.
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_EDITOR"] = "true"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startTime = Date()

        do {
            try process.run()
        } catch {
            throw AppError.unknown("Failed to launch \(command): \(error.localizedDescription)")
        }

        // Track whether the process was killed due to timeout
        let timedOut = OSAllocatedUnfairLock(initialState: false)

        // Set up timeout task that will terminate the process if it runs too long
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                timedOut.withLock { $0 = true }
                process.terminate()
            }
        }

        // Read stdout and stderr concurrently to avoid pipe buffer deadlocks
        let stdoutData: Data
        let stderrData: Data
        async let stdoutRead = Task.detached {
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let stderrRead = Task.detached {
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        stdoutData = await stdoutRead
        stderrData = await stderrRead

        process.waitUntilExit()
        timeoutTask.cancel()

        let duration = Date().timeIntervalSince(startTime)
        let stdoutString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
        let exitCode = process.terminationStatus

        let commandString = ([command] + arguments).joined(separator: " ")

        // Distinguish timeout from normal CLI failure
        let didTimeout = timedOut.withLock { $0 }
        if didTimeout {
            throw AppError.unknown(
                "Command '\(commandString)' timed out after \(Int(timeout)) seconds"
            )
        } // End of timeout check

        let result = CommandResult(
            exitCode: exitCode,
            stdout: stdoutString,
            stderr: stderrString,
            duration: duration,
            command: commandString
        )

        if throwOnFailure && exitCode != 0 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: exitCode,
                stderr: stderrString
            )
        }

        return result
    } // End of static func run(command:arguments:timeout:throwOnFailure:)
} // End of enum ProcessRunner
