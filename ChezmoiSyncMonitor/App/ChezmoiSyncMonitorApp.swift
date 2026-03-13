import SwiftUI
import os

/// Main entry point for the Chezmoi Sync Monitor menu bar application.
///
/// Creates the shared `AppStateStore` and injects it into the view hierarchy
/// via the SwiftUI environment. Handles missing CLI binaries gracefully by
/// showing an error state in the UI instead of crashing.
@main
struct ChezmoiSyncMonitorApp: App {

    /// The app delegate that handles notification tap events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Environment action to open windows by identifier.
    @Environment(\.openWindow) private var openWindow

    /// Logger for app-level events.
    private static let logger = Logger(
        subsystem: "cc.carpio.ChezmoiSyncMonitor",
        category: "App"
    )

    /// The shared application state store, created once at launch.
    @State private var appState: AppStateStore = Self.createAppState()

    /// An initialization error message if services could not be created.
    @State private var initError: String? = Self.initializationError

    /// The status icon configuration derived from current app state.
    private var statusIcon: StatusIconProvider.IconConfig {
        StatusIconProvider.icon(
            for: appState.snapshot.overallState,
            refreshState: appState.refreshState,
            isOnline: appState.isOnline
        )
    }

    /// The global keyboard shortcut service, if a shortcut is registered.
    @State private var shortcutService: GlobalShortcutService?

    /// Tracks whether services have been started.
    @State private var servicesStarted = false

    /// Whether the onboarding sheet is being shown.
    @State private var showOnboarding = false

    /// Stored initialization error from the factory method (nonisolated).
    private static nonisolated(unsafe) var initializationError: String?

    /// Creates the AppStateStore, falling back to a stub store if binaries are missing.
    ///
    /// Reads saved preferences to honor user-configured tool path overrides.
    /// Logs the error and records it for UI display rather than crashing.
    /// - Returns: An `AppStateStore` instance (functional or stub-based).
    private static func createAppState() -> AppStateStore {
        let savedPrefs = PreferencesStore().load()

        do {
            let chezmoiPath = savedPrefs.chezmoiPathOverride?.isEmpty == false
                ? savedPrefs.chezmoiPathOverride : nil
            let gitPath = savedPrefs.gitPathOverride?.isEmpty == false
                ? savedPrefs.gitPathOverride : nil

            let chezmoi = try ChezmoiService(binaryPath: chezmoiPath)
            let git = try GitService(gitPath: gitPath, chezmoiPath: chezmoiPath)
            let engine = FileStateEngine()
            return AppStateStore(
                chezmoiService: chezmoi,
                gitService: git,
                fileStateEngine: engine
            )
        } catch {
            let message = error.localizedDescription
            logger.error("Failed to initialize services: \(message, privacy: .public)")
            initializationError = message

            // Create a stub store that will show an error state in the UI.
            // The user can configure correct paths in Preferences.
            let stubChezmoi = StubChezmoiService()
            let stubGit = StubGitService()
            let engine = FileStateEngine()
            return AppStateStore(
                chezmoiService: stubChezmoi,
                gitService: stubGit,
                fileStateEngine: engine
            )
        }
    } // End of static func createAppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(nsImage: statusIcon.image)
                .accessibilityLabel(Text(Strings.app.accessibilityLabel))
                .onReceive(NotificationCenter.default.publisher(for: .openDashboard)) { _ in
                    openWindow(id: "dashboard")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .task {
                    guard !servicesStarted else { return }
                    servicesStarted = true

                    // Handle cold-launch notification tap that fired before .onReceive subscribed
                    if appDelegate.pendingDashboardOpen {
                        appDelegate.pendingDashboardOpen = false
                        openWindow(id: "dashboard")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }

                    // If initialization failed, set the error state immediately
                    if let errorMsg = initError {
                        appState.refreshState = .error(
                            .unknown("CLI binaries not found: \(errorMsg). Configure paths in Preferences.")
                        )
                        return
                    }

                    // Check if onboarding is needed
                    if !appState.hasCompletedOnboarding {
                        showOnboarding = true
                    }

                    await appState.startServices()

                    // Register saved global shortcut if configured
                    registerDashboardShortcut()
                }
                .onReceive(NotificationCenter.default.publisher(for: .dashboardShortcutChanged)) { _ in
                    registerDashboardShortcut()
                }
        }
        .menuBarExtraStyle(.window)

        Window("Chezmoi Sync Monitor", id: "dashboard") {
            DashboardView(appState: appState)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(appState: appState) {
                        showOnboarding = false
                    }
                }
        }

        Settings {
            PreferencesView(appState: appState)
        }
    } // End of computed property body

    /// Registers or re-registers the global dashboard shortcut from saved preferences.
    ///
    /// Unregisters any existing shortcut first, then attempts to register the new one.
    /// If no shortcut is configured, simply clears the service.
    private func registerDashboardShortcut() {
        shortcutService?.unregister()
        shortcutService = nil

        guard let shortcut = appState.preferences.dashboardShortcut else { return }

        let service = GlobalShortcutService {
            NotificationCenter.default.post(name: .openDashboard, object: nil)
        }

        if service.register(shortcut: shortcut) {
            shortcutService = service
        } else {
            Self.logger.warning("Failed to register dashboard shortcut: \(shortcut.displayString)")
        }
    } // End of func registerDashboardShortcut()
} // End of struct ChezmoiSyncMonitorApp

// MARK: - Stub services for graceful degradation

/// A stub ChezmoiService that always fails, used when the chezmoi binary is not found.
private struct StubChezmoiService: ChezmoiServiceProtocol {
    /// Always throws an error indicating chezmoi is not configured.
    func status() async throws -> [FileStatus] {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func diff(for path: String) async throws -> String {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func add(path: String) async throws -> CommandResult {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func update() async throws -> CommandResult {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func pullSource() async throws -> CommandResult {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func apply(path: String) async throws -> CommandResult {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func commitAndPush(message: String) async throws {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func sourcePath(for path: String) async throws -> String {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func trackedFiles() async throws -> Set<String> {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func gitAutomationConfig() async throws -> GitAutomationConfig {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating chezmoi is not configured.
    func forget(path: String) async throws -> CommandResult {
        throw AppError.unknown("chezmoi binary not found. Configure the path in Preferences.")
    }
} // End of struct StubChezmoiService

/// A stub GitService that always fails, used when the git binary is not found.
private struct StubGitService: GitServiceProtocol {
    /// Always throws an error indicating git is not configured.
    func fetch() async throws -> CommandResult {
        throw AppError.unknown("git binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating git is not configured.
    func aheadBehind() async throws -> (ahead: Int, behind: Int) {
        throw AppError.unknown("git binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating git is not configured.
    func remoteChangedFiles() async throws -> Set<String> {
        throw AppError.unknown("git binary not found. Configure the path in Preferences.")
    }

    /// Always throws an error indicating git is not configured.
    func remoteFileDiff(for sourcePath: String) async throws -> String {
        throw AppError.unknown("git binary not found. Configure the path in Preferences.")
    }
} // End of struct StubGitService
