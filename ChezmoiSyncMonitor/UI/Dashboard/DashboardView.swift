import SwiftUI
import UniformTypeIdentifiers

/// Represents the filter options available in the file list dropdown.
private enum FileFilter: CaseIterable {
    case needsAttention
    case all
    case localDrift
    case remoteDrift
    case dualDrift
    case error
    case clean

    /// The localized display name for the filter option.
    var displayName: String {
        switch self {
        case .needsAttention: return Strings.filters.needsAttention
        case .all: return Strings.filters.all
        case .localDrift: return Strings.filters.localDrift
        case .remoteDrift: return Strings.filters.remoteDrift
        case .dualDrift: return Strings.filters.dualDrift
        case .error: return Strings.filters.error
        case .clean: return Strings.filters.clean
        }
    } // End of computed property displayName

    /// Maps the filter to the corresponding FileSyncState, if any.
    var syncState: FileSyncState? {
        switch self {
        case .needsAttention: return nil  // special handling in filteredFiles
        case .all: return nil
        case .localDrift: return .localDrift
        case .remoteDrift: return .remoteDrift
        case .dualDrift: return .dualDrift
        case .error: return .error
        case .clean: return .clean
        }
    } // End of computed property syncState
} // End of enum FileFilter

/// Payload for the diff viewer sheet, bundling path and diff text so
/// the sheet only opens once both are ready.
private struct DiffPayload: Identifiable {
    let id = UUID()
    let filePath: String
    let diffText: String
} // End of struct DiffPayload

/// Dashboard window showing an overview of chezmoi-managed dotfiles sync state.
///
/// Displays overview cards, a filterable file list with contextual actions,
/// a diff viewer sheet, and a collapsible activity log.
struct DashboardView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// The currently selected filter for the file list.
    @State private var selectedFilter: FileFilter = .needsAttention

    /// The search text for filtering files by path.
    @State private var searchText = ""

    /// Payload for the diff viewer sheet. Non-nil triggers presentation.
    @State private var diffPayload: DiffPayload?

    /// The file path pending a destructive apply confirmation.
    @State private var applyConfirmationPath: String?

    /// Whether the apply confirmation dialog is shown.
    @State private var showingApplyConfirmation = false

    /// The file path pending a destructive revert confirmation.
    @State private var revertConfirmationPath: String?

    /// Whether the revert confirmation dialog is shown.
    @State private var showingRevertConfirmation = false

    /// The file path pending forget step 1 confirmation.
    @State private var forgetStep1Path: String?

    /// Whether the forget step 1 alert is shown.
    @State private var showingForgetStep1 = false

    /// The file path pending forget step 2 (typed gate) confirmation.
    @State private var forgetStep2Path: String?

    /// Whether the forget step 2 sheet is shown.
    @State private var showingForgetStep2 = false

    /// The text the user types to confirm the forget action.
    @State private var forgetConfirmationText = ""

    /// Whether a drag-and-drop operation is currently hovering over the file list.
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if appState.isViewOnlyMode, let warning = appState.viewOnlyWarning {
                viewOnlyBanner(warning: warning)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            Divider()

            // Overview cards
            overviewCards
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // Filter and search bar
            filterBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // File list
            fileListSection
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
                .sheet(isPresented: $showingForgetStep2) {
                    VStack(spacing: 16) {
                        Text(Strings.confirmations.forgetConfirmTitle)
                            .font(.headline)

                        Text(Strings.confirmations.forgetConfirmMessage("FORGET"))
                            .foregroundStyle(.secondary)

                        TextField(Strings.confirmations.forgetConfirmPlaceholder, text: $forgetConfirmationText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)

                        if !forgetConfirmationText.isEmpty && forgetConfirmationText != "FORGET" {
                            Text(Strings.confirmations.forgetConfirmMismatch)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        HStack(spacing: 12) {
                            Button(Strings.navigation.cancel) {
                                showingForgetStep2 = false
                                forgetStep2Path = nil
                                forgetConfirmationText = ""
                            }
                            .keyboardShortcut(.escape, modifiers: [])

                            Button(Strings.confirmations.forgetConfirmButton) {
                                if let path = forgetStep2Path {
                                    showingForgetStep2 = false
                                    forgetConfirmationText = ""
                                    Task {
                                        await appState.forgetSingle(path: path)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(forgetConfirmationText != "FORGET" || appState.isViewOnlyMode)
                        } // End of HStack for forget step 2 buttons
                    } // End of VStack for forget step 2 sheet content
                    .padding(24)
                    .frame(minWidth: 400)
                } // End of forget step 2 sheet

            // Activity log
            ActivityLogView(events: appState.activityLog)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        } // End of outer VStack
        .frame(minWidth: 700, minHeight: 500)
        .sheet(item: $diffPayload) { payload in
            DiffViewerView(filePath: payload.filePath, diffText: payload.diffText)
        }
        .confirmationDialog(
            isApplyCreation ? Strings.dashboard.createLocalFile : Strings.dashboard.applyRemoteChanges,
            isPresented: $showingApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                isApplyCreation ? Strings.dashboard.createLocal : Strings.dashboard.apply,
                role: isApplyCreation ? .none : .destructive
            ) {
                if let path = applyConfirmationPath {
                    Task {
                        await appState.updateSingle(path: path)
                    }
                }
            }
            Button(Strings.navigation.cancel, role: .cancel) {
                applyConfirmationPath = nil
            }
        } message: {
            Text(isApplyCreation ? Strings.dashboard.createLocalFileMessage : Strings.dashboard.applyWarning)
        }
        .confirmationDialog(
            Strings.confirmations.revertTitle,
            isPresented: $showingRevertConfirmation,
            titleVisibility: .visible
        ) {
            Button(Strings.confirmations.revertButton, role: .destructive) {
                if let path = revertConfirmationPath {
                    Task {
                        await appState.revertLocal(path: path)
                    }
                }
            }
            Button(Strings.navigation.cancel, role: .cancel) {
                revertConfirmationPath = nil
            }
        } message: {
            Text(Strings.confirmations.revertMessage)
        } // End of revert confirmation dialog
        .alert(
            Strings.confirmations.forgetTitle,
            isPresented: $showingForgetStep1
        ) {
            Button(Strings.confirmations.forgetContinue) {
                forgetStep2Path = forgetStep1Path
                forgetConfirmationText = ""
                showingForgetStep2 = true
            }
            Button(Strings.navigation.cancel, role: .cancel) {
                forgetStep1Path = nil
            }
        } message: {
            Text(Strings.confirmations.forgetMessage)
        } // End of forget step 1 alert
    } // End of body

    // MARK: - Header Section

    /// The header showing the app title and refresh status indicator.
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.dashboard.title)
                    .font(.title)
                    .fontWeight(.semibold)
                Text(Strings.dashboard.version(appState.appVersionDisplay))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            refreshStateIndicator

            Button {
                Task {
                    await appState.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        } // End of header HStack
    } // End of headerSection

    /// A warning banner shown when the app enters view-only safety mode.
    private func viewOnlyBanner(warning: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.safety.viewOnlyTitle)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
    } // End of func viewOnlyBanner(warning:)

    /// Displays the current refresh state as text or a spinner.
    @ViewBuilder
    private var refreshStateIndicator: some View {
        switch appState.refreshState {
        case .idle:
            Text(Strings.dashboard.notRefreshedYet)
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(Strings.dashboard.refreshing)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .success(let date):
            Text(Strings.dashboard.lastRefresh(RelativeTimeFormatter.string(for: date)))
                .font(.callout)
                .foregroundStyle(.secondary)
        case .error(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        case .stale:
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text(Strings.dashboard.dataIsStale)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } // End of switch refreshState
    } // End of refreshStateIndicator

    /// Whether a refresh operation is currently running.
    private var isRefreshing: Bool {
        if case .running = appState.refreshState { return true }
        return false
    } // End of isRefreshing

    /// Whether the pending apply confirmation is for a file creation (localMissing)
    /// rather than a destructive overwrite.
    private var isApplyCreation: Bool {
        guard let path = applyConfirmationPath else { return false }
        return appState.snapshot.files.first(where: { $0.path == path })?.localMissing == true
    } // End of isApplyCreation

    // MARK: - Overview Cards

    /// The horizontal row of overview cards showing aggregate counts.
    private var overviewCards: some View {
        HStack(spacing: 12) {
            OverviewCardView(
                iconName: "square.grid.2x2",
                count: appState.snapshot.files.count,
                label: Strings.overviewCards.all,
                color: .blue,
                isSelected: selectedFilter == .all,
                action: { toggleFilter(.all) }
            )

            OverviewCardView(
                iconName: "exclamationmark.circle.fill",
                count: appState.snapshot.needsAttentionCount,
                label: Strings.overviewCards.needsAttention,
                color: .orange,
                isSelected: selectedFilter == .needsAttention,
                action: { selectedFilter = .needsAttention }
            )

            OverviewCardView(
                iconName: FileSyncState.localDrift.iconName,
                count: appState.snapshot.localDriftCount,
                label: Strings.overviewCards.localDrift,
                color: FileSyncState.localDrift.color,
                isSelected: selectedFilter == .localDrift,
                action: { toggleFilter(.localDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.remoteDrift.iconName,
                count: appState.snapshot.remoteDriftCount,
                label: Strings.overviewCards.remoteDrift,
                color: FileSyncState.remoteDrift.color,
                isSelected: selectedFilter == .remoteDrift,
                action: { toggleFilter(.remoteDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.dualDrift.iconName,
                count: appState.snapshot.conflictCount,
                label: Strings.overviewCards.conflicts,
                color: FileSyncState.dualDrift.color,
                isSelected: selectedFilter == .dualDrift,
                action: { toggleFilter(.dualDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.error.iconName,
                count: appState.snapshot.errorCount,
                label: Strings.overviewCards.errors,
                color: FileSyncState.error.color,
                isSelected: selectedFilter == .error,
                action: { toggleFilter(.error) }
            )
        } // End of HStack for overview cards
    } // End of overviewCards

    /// Toggles a filter on or off; clicking an already-selected filter resets to "Needs Attention".
    /// - Parameter filter: The filter to toggle.
    private func toggleFilter(_ filter: FileFilter) {
        if selectedFilter == filter {
            selectedFilter = .needsAttention
        } else {
            selectedFilter = filter
        }
    } // End of func toggleFilter(_:)

    // MARK: - Filter Bar

    /// The filter dropdown and search field above the file list.
    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(Strings.dashboard.filter)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedFilter) {
                    ForEach(FileFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                } // End of Picker
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            HStack(spacing: 6) {
                Text(Strings.dashboard.search)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField(Strings.dashboard.filterByPath, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        } // End of HStack for filter bar
    } // End of filterBar

    // MARK: - File List

    /// The filtered and searchable list of managed files.
    private var fileListSection: some View {
        GroupBox {
            if filteredFiles.isEmpty {
                emptyFileListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFiles) { file in
                            FileListItemView(
                                file: file,
                                isViewOnlyMode: appState.isViewOnlyMode,
                                onAdd: { path in
                                    Task { await appState.addSingle(path: path) }
                                },
                                onApply: { path in
                                    applyConfirmationPath = path
                                    showingApplyConfirmation = true
                                },
                                onDiff: { path in
                                    Task { @MainActor in
                                        await appState.loadDiff(for: path)
                                        if let diff = appState.currentDiff {
                                            diffPayload = DiffPayload(filePath: path, diffText: diff)
                                        }
                                    }
                                },
                                onEdit: { path in
                                    appState.openInEditor(path: path)
                                },
                                onMerge: { path in
                                    Task { await appState.openInMergeTool(path: path) }
                                },
                                onRevert: { path in
                                    revertConfirmationPath = path
                                    showingRevertConfirmation = true
                                },
                                onForget: { path in
                                    forgetStep1Path = path
                                    showingForgetStep1 = true
                                }
                            )

                            if file.id != filteredFiles.last?.id {
                                Divider()
                            }
                        } // End of ForEach over files
                    } // End of LazyVStack
                } // End of ScrollView
            } // End of else (files not empty)
        } label: {
            HStack {
                Text(Strings.dashboard.managedFiles)
                    .font(.headline)

                Text("(\(filteredFiles.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        } // End of GroupBox
        .overlay {
            if isDropTargeted && selectedFilter == .all {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .foregroundStyle(.blue.opacity(0.5))
            }
        } // End of drop target overlay
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            guard selectedFilter == .all else { return false }
            let homeURL = FileManager.default.homeDirectoryForCurrentUser

            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    let homePath = homeURL.path
                    var relativePath = url.path
                    // Strip home directory prefix to get a relative path for chezmoi
                    if relativePath.hasPrefix(homePath + "/") {
                        relativePath = String(relativePath.dropFirst(homePath.count + 1))
                    } else if relativePath.hasPrefix(homePath) && relativePath.count == homePath.count {
                        return // Dropped the home directory itself — ignore
                    }
                    Task { @MainActor in
                        await appState.addSingle(path: relativePath)
                    }
                } // End of provider.loadObject callback
            } // End of for loop over providers
            return true
        } // End of onDrop modifier
    } // End of fileListSection

    /// The view shown when no files match the current filter/search.
    private var emptyFileListView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            if appState.snapshot.files.isEmpty {
                Text(Strings.dashboard.noManagedFiles)
                    .foregroundStyle(.secondary)
                Text(Strings.dashboard.clickRefresh)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if selectedFilter == .all {
                    Text(Strings.dashboard.dropFilesHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            } else {
                Text(Strings.dashboard.noFilesMatchFilter)
                    .foregroundStyle(.secondary)
                if selectedFilter == .all {
                    Text(Strings.dashboard.dropFilesHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                Button(Strings.dashboard.clearFilters) {
                    selectedFilter = .needsAttention
                    searchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } // End of VStack for empty state
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    } // End of emptyFileListView

    /// The files from the snapshot, filtered by the selected state filter and search text.
    private var filteredFiles: [FileStatus] {
        var files = appState.snapshot.files

        // Apply state filter
        switch selectedFilter {
        case .all:
            break  // show everything including clean
        case .needsAttention:
            files = files.filter { $0.state != .clean }
        case .localDrift:
            files = files.filter { $0.state == .localDrift }
        case .remoteDrift:
            files = files.filter { $0.state == .remoteDrift }
        case .dualDrift:
            files = files.filter { $0.state == .dualDrift }
        case .error:
            files = files.filter { $0.state == .error }
        case .clean:
            files = files.filter { $0.state == .clean }
        } // End of switch selectedFilter

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            files = files.filter { $0.path.lowercased().contains(query) }
        }

        return files
    } // End of computed property filteredFiles
} // End of struct DashboardView
