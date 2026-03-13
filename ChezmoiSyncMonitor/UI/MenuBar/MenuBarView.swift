import SwiftUI

/// View displayed in the menu bar dropdown (window-style popover).
///
/// Shows a status summary, per-state file counts, quick actions
/// (refresh, add local, commit & push, apply remote), and navigation
/// to the dashboard and preferences.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    /// The shared application state store.
    let appState: AppStateStore

    /// Whether a refresh operation is currently in progress.
    private var isRefreshing: Bool {
        if case .running = appState.refreshState { return true }
        return false
    }

    /// The text to display for the last refresh timestamp.
    private var lastRefreshText: String {
        if isRefreshing {
            return Strings.menu.refreshing
        }
        guard let date = appState.snapshot.lastRefreshAt else {
            return Strings.menu.never
        }
        return RelativeTimeFormatter.string(for: date)
    } // End of computed property lastRefreshText

    /// The status icon configuration based on current state.
    private var statusIcon: StatusIconProvider.IconConfig {
        StatusIconProvider.icon(
            for: appState.snapshot.overallState,
            refreshState: appState.refreshState,
            isOnline: appState.isOnline
        )
    }

    /// Whether there are any drifted files at all.
    private var hasAnyDrift: Bool {
        appState.snapshot.localDriftCount > 0
            || appState.snapshot.remoteDriftCount > 0
            || appState.snapshot.conflictCount > 0
            || appState.snapshot.errorCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Offline banner
            if !appState.isOnline {
                offlineBanner
                Divider()
                    .padding(.horizontal, 12)
            }

            // MARK: - View-only safety banner
            if appState.isViewOnlyMode, let warning = appState.viewOnlyWarning {
                viewOnlyBanner(message: warning)
                Divider()
                    .padding(.horizontal, 12)
            }

            // MARK: - Header section
            headerSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Count rows section
            countSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Actions section
            actionsSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Navigation section
            navigationSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Quit
            menuButton(
                Strings.menu.quit,
                icon: "power"
            ) {
                // Close all windows first to dismiss any modal sheets that
                // would block NSApplication.terminate.
                for window in NSApplication.shared.windows {
                    window.close()
                }
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 280)
    } // End of computed property body

    // MARK: - Header

    /// The top header showing the app name with a status indicator and last refresh time.
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(nsImage: statusIcon.image)
                .foregroundStyle(statusIcon.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.menu.title)
                    .fontWeight(.semibold)
                Text(Strings.menu.lastRefresh(lastRefreshText))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Strings.menu.version(appState.appVersionDisplay))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    } // End of computed property headerSection

    // MARK: - Offline banner

    /// A non-intrusive inline banner shown when the network is unreachable.
    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(Strings.menu.offline)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                if let lastRefresh = appState.snapshot.lastRefreshAt {
                    Text(Strings.menu.lastCheck(RelativeTimeFormatter.string(for: lastRefresh)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    } // End of computed property offlineBanner

    /// Warning banner shown when mutating actions are disabled by safety checks.
    private func viewOnlyBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.safety.viewOnlyTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    } // End of func viewOnlyBanner(message:)

    // MARK: - Counts

    /// Rows showing per-state file counts, only visible when count > 0.
    private var countSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.snapshot.localDriftCount > 0 {
                countRow(
                    icon: FileSyncState.localDrift.iconName,
                    color: FileSyncState.localDrift.color,
                    count: appState.snapshot.localDriftCount,
                    labelSingular: Strings.menu.localChangeSingular,
                    labelPlural: Strings.menu.localChangePlural
                )
            }

            if appState.snapshot.remoteDriftCount > 0 {
                countRow(
                    icon: FileSyncState.remoteDrift.iconName,
                    color: FileSyncState.remoteDrift.color,
                    count: appState.snapshot.remoteDriftCount,
                    labelSingular: Strings.menu.remoteChangeSingular,
                    labelPlural: Strings.menu.remoteChangePlural
                )
            }

            if appState.snapshot.conflictCount > 0 {
                countRow(
                    icon: FileSyncState.dualDrift.iconName,
                    color: FileSyncState.dualDrift.color,
                    count: appState.snapshot.conflictCount,
                    labelSingular: Strings.menu.conflictSingular,
                    labelPlural: Strings.menu.conflictPlural
                )
            }

            if appState.snapshot.errorCount > 0 {
                countRow(
                    icon: FileSyncState.error.iconName,
                    color: FileSyncState.error.color,
                    count: appState.snapshot.errorCount,
                    labelSingular: Strings.menu.errorSingular,
                    labelPlural: Strings.menu.errorPlural
                )
            }

            // Show "all clean" message when nothing is drifted
            if !hasAnyDrift {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(Strings.menu.allClean)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 2)
    } // End of computed property countSection

    // MARK: - Actions

    /// Quick action buttons: refresh, add local changes, commit & push, apply remote.
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(
                Strings.menu.refreshNow,
                icon: "arrow.clockwise",
                disabled: isRefreshing
            ) {
                Task { await appState.refresh() }
            }

            menuButton(
                Strings.menu.addLocalChanges,
                icon: "plus.circle",
                disabled: appState.snapshot.localDriftCount == 0 || isRefreshing || appState.isViewOnlyMode
            ) {
                Task { await appState.addAllSafe() }
            }

            menuButton(
                Strings.menu.commitAndPush,
                icon: "arrow.up.circle",
                disabled: isRefreshing || appState.isViewOnlyMode
            ) {
                Task { await appState.commitAndPush() }
            }

            if appState.preferences.batchSafeSyncEnabled {
                menuButton(
                    Strings.menu.applySafeRemote,
                    icon: "arrow.down.circle",
                    disabled: appState.snapshot.remoteDriftCount == 0 || isRefreshing || appState.isViewOnlyMode
                ) {
                    Task { await appState.updateSafe() }
                }
            }
        }
    } // End of computed property actionsSection

    // MARK: - Navigation

    /// Links to the dashboard window and preferences.
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(
                Strings.menu.openDashboard,
                icon: "rectangle.grid.1x2"
            ) {
                openWindow(id: "dashboard")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            menuButton(
                Strings.menu.preferences,
                icon: "gearshape"
            ) {
                openPreferences()
            }
        }
    } // End of computed property navigationSection

    // MARK: - Helpers

    /// Opens the macOS Settings/Preferences window programmatically.
    private func openPreferences() {
        openSettings()
        NSApplication.shared.activate(ignoringOtherApps: true)
    } // End of func openPreferences()

    /// Builds a single count row with an icon, count value, and singular/plural label.
    /// - Parameters:
    ///   - icon: The SF Symbol name for the row icon.
    ///   - color: The tint color for the icon.
    ///   - count: The number to display.
    ///   - labelSingular: The singular description text (e.g., "local change").
    ///   - labelPlural: The plural description text (e.g., "local changes").
    /// - Returns: A styled HStack view.
    private func countRow(
        icon: String,
        color: Color,
        count: Int,
        labelSingular: String,
        labelPlural: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count) \(count == 1 ? labelSingular : labelPlural)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    } // End of func countRow(icon:color:count:labelSingular:labelPlural:)

    /// A reusable button styled to look like a menu item with hover highlight.
    /// - Parameters:
    ///   - title: The button label text.
    ///   - icon: The SF Symbol name.
    ///   - disabled: Whether the button is disabled.
    ///   - action: The closure to run on tap.
    /// - Returns: A styled button view.
    private func menuButton(
        _ title: String,
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuItemButtonStyle())
        .disabled(disabled)
    } // End of func menuButton(_:icon:disabled:action:)
} // End of struct MenuBarView

/// A button style that mimics macOS menu item appearance with hover highlight.
struct MenuItemButtonStyle: ButtonStyle {
    @State private var isHovered = false

    /// Creates the styled button body with hover and press states.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed
                          ? Color.accentColor.opacity(0.3)
                          : isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
    } // End of func makeBody(configuration:)
} // End of struct MenuItemButtonStyle
