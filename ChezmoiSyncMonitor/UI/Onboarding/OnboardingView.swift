import SwiftUI
import UserNotifications

/// A multi-step onboarding sheet shown on first launch.
///
/// Guides the user through dependency detection, notification permissions,
/// and initial configuration before starting monitoring.
struct OnboardingView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// Callback invoked when onboarding is complete.
    let onComplete: () -> Void

    /// The current onboarding step (0-indexed).
    @State private var currentStep = 0

    /// The detected chezmoi binary path, if found.
    @State private var detectedChezmoiPath: String?

    /// The detected git binary path, if found.
    @State private var detectedGitPath: String?

    /// The detected source repo path, if found.
    @State private var detectedSourceRepoPath: String?

    /// Whether notification authorization was granted.
    @State private var notificationAuthorized = false

    /// Whether dependency detection has been performed.
    @State private var hasDetected = false

    /// Total number of onboarding steps.
    private static let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    dependenciesStep
                case 2:
                    permissionsStep
                case 3:
                    doneStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Step indicator and navigation
            HStack {
                stepIndicator

                Spacer()

                navigationButtons
            }
            .padding()
        }
        .frame(width: 520, height: 480)
    } // End of computed property body

    // MARK: - Step 1: Welcome

    /// Welcome step explaining what the app does.
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(Strings.onboarding.welcome)
                .font(.title)
                .fontWeight(.bold)

            Text(Strings.onboarding.welcomeDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    } // End of computed property welcomeStep

    // MARK: - Step 2: Dependencies

    /// Dependency check step that auto-detects chezmoi, git, and source repo.
    private var dependenciesStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(Strings.onboarding.checkDependencies)
                .font(.title2)
                .fontWeight(.bold)

            Text(Strings.onboarding.dependenciesDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                dependencyRow(
                    name: "chezmoi",
                    path: detectedChezmoiPath,
                    installURL: "https://www.chezmoi.io/install/"
                )

                dependencyRow(
                    name: "git",
                    path: detectedGitPath,
                    installURL: "https://git-scm.com/download/mac"
                )

                dependencyRow(
                    name: "Source repository",
                    path: detectedSourceRepoPath,
                    installURL: nil
                )
            }
            .padding(.horizontal, 40)

            if !hasDetected {
                Button(Strings.onboarding.detect) {
                    detectDependencies()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(Strings.onboarding.redetect) {
                    detectDependencies()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if !hasDetected {
                detectDependencies()
            }
        }
    } // End of computed property dependenciesStep

    // MARK: - Step 3: Permissions

    /// Permissions step requesting notification authorization and Full Disk Access.
    private var permissionsStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text(Strings.onboarding.permissions)
                .font(.title2)
                .fontWeight(.bold)

            Text(Strings.onboarding.permissionsDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            // Full Disk Access section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.onboarding.fullDiskAccess)
                            .fontWeight(.medium)
                        Text(Strings.onboarding.fullDiskAccessDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(Strings.onboarding.openSettings) {
                        openFullDiskAccessSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } // End of HStack for Full Disk Access row

                Divider()

                // Notifications section
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.onboarding.notifications)
                            .fontWeight(.medium)
                        Text(Strings.onboarding.notificationsDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if notificationAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button(Strings.onboarding.enableNotifications) {
                            Task {
                                await requestNotificationPermission()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } // End of HStack for Notifications row
            } // End of VStack for permission rows
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            .padding(.horizontal, 40)

            Text(Strings.onboarding.permissionsOptional)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    } // End of computed property permissionsStep

    // MARK: - Step 4: Done

    /// Final summary step before starting monitoring.
    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(Strings.onboarding.allSet)
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow("chezmoi", value: detectedChezmoiPath ?? Strings.onboarding.notFound)
                summaryRow("git", value: detectedGitPath ?? Strings.onboarding.notFound)
                summaryRow(Strings.onboarding.sourceRepo, value: detectedSourceRepoPath ?? Strings.onboarding.notFound)
                summaryRow(Strings.onboarding.notifications, value: notificationAuthorized ? Strings.onboarding.enabled : Strings.onboarding.disabled)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    } // End of computed property doneStep

    // MARK: - Navigation

    /// Dot indicators showing current step progress.
    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<OnboardingView.totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            } // End of ForEach step indicators
        }
    } // End of computed property stepIndicator

    /// Back/Next/Done navigation buttons.
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(Strings.navigation.back) {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }

            if currentStep < OnboardingView.totalSteps - 1 {
                Button(Strings.navigation.next) {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(Strings.navigation.startMonitoring) {
                    appState.completeOnboarding()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    } // End of computed property navigationButtons

    // MARK: - Helper Views

    /// A row showing a dependency name with a checkmark or warning icon and its path.
    /// - Parameters:
    ///   - name: The dependency display name.
    ///   - path: The detected path, or nil if not found.
    ///   - installURL: An optional URL string for installation instructions.
    @ViewBuilder
    private func dependencyRow(name: String, path: String?, installURL: String?) -> some View {
        HStack(spacing: 10) {
            if path != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.medium)

                if let path = path {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let urlString = installURL {
                    Link(Strings.onboarding.installInstructions, destination: URL(string: urlString)!)
                        .font(.caption)
                } else {
                    Text(Strings.onboarding.sourceRepoNotFound)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    } // End of func dependencyRow(name:path:installURL:)

    /// A summary row showing a label and its value.
    /// - Parameters:
    ///   - label: The configuration item name.
    ///   - value: The detected value string.
    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    } // End of func summaryRow(_:value:)

    // MARK: - Actions

    /// Detects all dependencies and updates state.
    private func detectDependencies() {
        detectedChezmoiPath = PATHResolver.chezmoiPath()
        detectedGitPath = PATHResolver.gitPath()
        detectSourceRepoPath()
        hasDetected = true
    } // End of func detectDependencies()

    /// Detects the source repo path by running chezmoi source-path.
    private func detectSourceRepoPath() {
        guard let chezmoiBinary = detectedChezmoiPath ?? PATHResolver.chezmoiPath() else {
            detectedSourceRepoPath = nil
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: chezmoiBinary)
        process.arguments = ["source-path"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    detectedSourceRepoPath = path
                    return
                }
            }
        } catch {
            // Fall through to nil
        }

        detectedSourceRepoPath = nil
    } // End of func detectSourceRepoPath()

    /// Requests notification permission from the system.
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                notificationAuthorized = granted
            }
        } catch {
            await MainActor.run {
                notificationAuthorized = false
            }
        }
    } // End of func requestNotificationPermission()

    /// Opens System Settings to the Full Disk Access pane.
    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    } // End of func openFullDiskAccessSettings()
} // End of struct OnboardingView
