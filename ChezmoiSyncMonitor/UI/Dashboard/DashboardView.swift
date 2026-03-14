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
/// a two-pane layout with bundles, a diff viewer sheet, and a collapsible activity log.
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

    /// The currently selected bundle in the main pane, or nil for no selection.
    @State private var selectedBundleId: UUID?

    /// Whether the "New Bundle" name input alert is shown.
    @State private var showingNewBundleDialog = false

    /// The text field value for new/rename bundle dialogs.
    @State private var bundleNameInput = ""

    /// Whether the rename bundle dialog is shown.
    @State private var showingRenameBundleDialog = false

    /// Whether the delete bundle confirmation is shown.
    @State private var showingDeleteBundleConfirmation = false

    /// File path pending assignment when creating a new bundle from a context menu.
    /// When set, the newly created bundle will automatically get this file assigned.
    @State private var pendingAssignmentPath: String?

    /// Set of file paths currently selected for bulk bundle assignment.
    @State private var selectedFilePaths: Set<String> = []

    /// Whether multi-select mode is active.
    @State private var isMultiSelectMode = false

    /// Paths pending assignment when creating a new bundle from bulk selection.
    @State private var pendingBulkAssignmentPaths: [String]?

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

            // Selection action bar (visible when files are selected)
            if isMultiSelectMode {
                selectionActionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }

            // File list (two-pane layout)
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
        .frame(minWidth: 1000, minHeight: 500)
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
        // New Bundle dialog
        .alert(Strings.bundles.newBundle, isPresented: $showingNewBundleDialog) {
            TextField(Strings.bundles.bundleNamePlaceholder, text: $bundleNameInput)
            Button(Strings.navigation.cancel, role: .cancel) {
                bundleNameInput = ""
                pendingAssignmentPath = nil
                pendingBulkAssignmentPaths = nil
            }
            Button(Strings.bundles.newBundle) {
                let name = bundleNameInput.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    if let newBundle = appState.createBundle(name: name) {
                        // Auto-assign pending files (single from context menu or bulk from selection bar)
                        if let paths = pendingBulkAssignmentPaths {
                            appState.assignFilesToBundle(paths: paths, bundleId: newBundle.id)
                            selectedFilePaths.subtract(paths)
                            isMultiSelectMode = false
                        } else if let path = pendingAssignmentPath {
                            appState.assignFileToBundle(path: path, bundleId: newBundle.id)
                        }
                    }
                }
                bundleNameInput = ""
                pendingAssignmentPath = nil
                pendingBulkAssignmentPaths = nil
            }
            .disabled(bundleNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(Strings.bundles.bundleName)
        } // End of new bundle alert
        // Rename Bundle dialog
        .alert(Strings.bundles.renameBundle, isPresented: $showingRenameBundleDialog) {
            TextField(Strings.bundles.bundleNamePlaceholder, text: $bundleNameInput)
            Button(Strings.navigation.cancel, role: .cancel) {
                bundleNameInput = ""
            }
            Button(Strings.bundles.renameBundle) {
                let name = bundleNameInput.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, let bundleId = selectedBundleId {
                    _ = appState.renameBundle(id: bundleId, newName: name)
                }
                bundleNameInput = ""
            }
            .disabled(bundleNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(Strings.bundles.bundleName)
        } // End of rename bundle alert
        // Delete Bundle confirmation
        .confirmationDialog(
            Strings.bundles.deleteBundleTitle,
            isPresented: $showingDeleteBundleConfirmation,
            titleVisibility: .visible
        ) {
            Button(Strings.bundles.deleteBundleButton, role: .destructive) {
                if let bundleId = selectedBundleId {
                    appState.deleteBundle(id: bundleId)
                    selectedBundleId = nil
                }
            }
            Button(Strings.navigation.cancel, role: .cancel) {}
        } message: {
            Text(Strings.bundles.deleteBundleMessage)
        } // End of delete bundle confirmation
        .onChange(of: appState.preferences.bundles) {
            // Clear selectedBundleId if the selected bundle was deleted
            if let selectedId = selectedBundleId,
               !appState.preferences.bundles.contains(where: { $0.id == selectedId }) {
                selectedBundleId = nil
            }
        } // End of onChange for bundles
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

    /// The filter dropdown, search field, and new bundle button above the file list.
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

            // Multi-select toggle
            Button {
                isMultiSelectMode.toggle()
                if !isMultiSelectMode {
                    selectedFilePaths.removeAll()
                }
            } label: {
                Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .toolTip(isMultiSelectMode ? Strings.bundles.clearSelection : Strings.bundles.assignSelected)

            Button {
                bundleNameInput = ""
                showingNewBundleDialog = true
            } label: {
                Image(systemName: "plus.rectangle.on.folder")
                Text(Strings.bundles.newBundle)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } // End of HStack for filter bar
    } // End of filterBar

    /// Action bar shown when multi-select mode is active, providing bulk assignment controls.
    private var selectionActionBar: some View {
        HStack(spacing: 10) {
            Text(Strings.bundles.selectionCount(selectedFilePaths.count))
                .font(.callout)
                .fontWeight(.medium)

            Button(Strings.bundles.selectAll) {
                for file in filteredUnbundledFiles {
                    selectedFilePaths.insert(file.path)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(Strings.bundles.clearSelection) {
                selectedFilePaths.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedFilePaths.isEmpty)

            Spacer()

            // Assign selected to bundle menu
            Menu {
                ForEach(appState.preferences.bundles.sorted(by: { $0.name < $1.name })) { bundle in
                    Button(bundle.name) {
                        appState.assignFilesToBundle(paths: Array(selectedFilePaths), bundleId: bundle.id)
                        selectedFilePaths.removeAll()
                        isMultiSelectMode = false
                    }
                } // End of ForEach over bundles in assign menu

                if !appState.preferences.bundles.isEmpty {
                    Divider()
                }

                Button(Strings.bundles.newBundle) {
                    bundleNameInput = ""
                    pendingBulkAssignmentPaths = Array(selectedFilePaths)
                    showingNewBundleDialog = true
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                Text(Strings.bundles.assignSelected)
            } // End of Menu for bulk assignment
            .menuStyle(.borderedButton)
            .controlSize(.small)
            .disabled(selectedFilePaths.isEmpty)
        } // End of HStack for selection action bar
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.08))
        )
    } // End of selectionActionBar

    // MARK: - Two-Pane File List

    /// The two-pane layout with unbundled files + bundles on the left and bundle detail on the right.
    private var fileListSection: some View {
        HSplitView {
            // Left pane: unbundled files + bundle rows
            mainPaneContent
                .frame(minWidth: 300)

            // Right pane: bundle detail or empty state
            detailPaneContent
                .frame(minWidth: 280)
        } // End of HSplitView
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

    /// The left pane showing unbundled files and bundle rows.
    private var mainPaneContent: some View {
        GroupBox {
            if filteredUnbundledFiles.isEmpty && filteredBundles.isEmpty {
                emptyFileListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Unbundled files
                        ForEach(filteredUnbundledFiles) { file in
                            FileListItemView(
                                file: file,
                                isViewOnlyMode: appState.isViewOnlyMode,
                                isSelectable: isMultiSelectMode,
                                isSelected: selectedFilePaths.contains(file.path),
                                onToggleSelection: { path in
                                    if selectedFilePaths.contains(path) {
                                        selectedFilePaths.remove(path)
                                    } else {
                                        selectedFilePaths.insert(path)
                                    }
                                },
                                onAdd: handleAdd,
                                onApply: handleApply,
                                onDiff: handleDiff,
                                onEdit: handleEdit,
                                onMerge: handleMerge,
                                onRevert: handleRevert,
                                onForget: handleForget
                            )
                            .contextMenu {
                                bundleAssignmentMenu(for: file.path)
                            }

                            Divider()
                        } // End of ForEach over unbundled files

                        // Bundles section
                        if !filteredBundles.isEmpty {
                            if !filteredUnbundledFiles.isEmpty {
                                HStack {
                                    Text(Strings.bundles.manageBundles)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }

                            ForEach(filteredBundles) { bundle in
                                BundleRowView(
                                    bundle: bundle,
                                    aggregateState: appState.bundleAggregateState(bundleId: bundle.id),
                                    stateCounts: appState.bundleStateCounts(bundleId: bundle.id),
                                    resolvedMemberCount: appState.bundleMembers(bundleId: bundle.id, from: appState.snapshot).count,
                                    isSelected: selectedBundleId == bundle.id,
                                    onDropPaths: { paths in
                                        appState.assignFilesToBundle(paths: paths, bundleId: bundle.id)
                                        selectedFilePaths.subtract(paths)
                                    }
                                )
                                .onTapGesture {
                                    selectedBundleId = bundle.id
                                }

                                if bundle.id != filteredBundles.last?.id {
                                    Divider()
                                }
                            } // End of ForEach over bundles
                        } // End of if filteredBundles not empty
                    } // End of LazyVStack
                } // End of ScrollView
            } // End of else (content not empty)
        } label: {
            HStack {
                Text(Strings.dashboard.managedFiles)
                    .font(.headline)

                let totalCount = filteredUnbundledFiles.count + filteredBundles.count
                Text("(\(totalCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        } // End of GroupBox
    } // End of mainPaneContent

    /// The right pane showing bundle detail or empty state.
    @ViewBuilder
    private var detailPaneContent: some View {
        if let bundleId = selectedBundleId,
           let bundle = appState.preferences.bundles.first(where: { $0.id == bundleId }) {
            let allMembers = appState.bundleMembers(bundleId: bundleId, from: appState.snapshot)
            let filtered = applyFilters(to: allMembers)
            BundleDetailView(
                bundle: bundle,
                filteredMembers: filtered,
                totalMemberCount: allMembers.count,
                isViewOnlyMode: appState.isViewOnlyMode,
                onAdd: handleAdd,
                onApply: handleApply,
                onDiff: handleDiff,
                onEdit: handleEdit,
                onMerge: handleMerge,
                onRevert: handleRevert,
                onForget: handleForget,
                onRename: {
                    bundleNameInput = bundle.name
                    showingRenameBundleDialog = true
                },
                onDelete: {
                    showingDeleteBundleConfirmation = true
                },
                onRemoveFromBundle: { path in
                    appState.removeFileFromBundle(path: path, bundleId: bundleId)
                }
            )
        } else {
            BundleEmptyDetailView()
        }
    } // End of detailPaneContent

    /// Context menu for assigning an unbundled file to an existing bundle or creating a new one.
    /// - Parameter path: The file path to assign.
    @ViewBuilder
    private func bundleAssignmentMenu(for path: String) -> some View {
        Menu(Strings.bundles.assignToBundle) {
            ForEach(appState.preferences.bundles.sorted(by: { $0.name < $1.name })) { bundle in
                Button(bundle.name) {
                    appState.assignFileToBundle(path: path, bundleId: bundle.id)
                }
            } // End of ForEach over bundles in context menu

            if !appState.preferences.bundles.isEmpty {
                Divider()
            }

            Button(Strings.bundles.newBundle) {
                bundleNameInput = ""
                pendingAssignmentPath = path
                showingNewBundleDialog = true
            }
        } // End of Menu for bundle assignment
    } // End of func bundleAssignmentMenu(for:)

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

    // MARK: - Filtered Data

    /// The unbundled files from the snapshot, filtered by the selected state filter and search text.
    private var filteredUnbundledFiles: [FileStatus] {
        let unbundled = appState.unbundledFiles(from: appState.snapshot)
        return applyFilters(to: unbundled)
    } // End of computed property filteredUnbundledFiles

    /// Bundles filtered by the current filter and search text.
    /// Hides all-clean bundles in non-All/non-Clean filters and hides bundles
    /// with zero matching members when search text is active.
    private var filteredBundles: [BundleDefinition] {
        appState.preferences.bundles
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            .filter { bundle in
                // State filter
                let aggregate = appState.bundleAggregateState(bundleId: bundle.id)
                let passesStateFilter: Bool
                switch selectedFilter {
                case .all:
                    passesStateFilter = true
                case .needsAttention:
                    passesStateFilter = aggregate != .clean
                case .clean:
                    passesStateFilter = aggregate == .clean
                default:
                    let counts = appState.bundleStateCounts(bundleId: bundle.id)
                    if let state = selectedFilter.syncState {
                        passesStateFilter = (counts[state] ?? 0) > 0
                    } else {
                        passesStateFilter = true
                    }
                }
                guard passesStateFilter else { return false }

                // Search filter: hide bundles with no matching members after applying both state and search filters
                if !searchText.isEmpty {
                    let members = appState.bundleMembers(bundleId: bundle.id, from: appState.snapshot)
                    let filteredMembers = applyFilters(to: members)
                    if filteredMembers.isEmpty { return false }
                }

                return true
            } // End of filter closure for bundles
    } // End of computed property filteredBundles

    /// Applies the current filter and search text to a list of files.
    /// - Parameter files: The files to filter.
    /// - Returns: The filtered file list.
    private func applyFilters(to files: [FileStatus]) -> [FileStatus] {
        var result = files

        // Apply state filter
        switch selectedFilter {
        case .all:
            break  // show everything including clean
        case .needsAttention:
            result = result.filter { $0.state != .clean }
        case .localDrift:
            result = result.filter { $0.state == .localDrift }
        case .remoteDrift:
            result = result.filter { $0.state == .remoteDrift }
        case .dualDrift:
            result = result.filter { $0.state == .dualDrift }
        case .error:
            result = result.filter { $0.state == .error }
        case .clean:
            result = result.filter { $0.state == .clean }
        } // End of switch selectedFilter

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.path.lowercased().contains(query) }
        }

        return result
    } // End of func applyFilters(to:)

    // MARK: - File Action Handlers

    /// Handles the "Add" action for a file.
    /// - Parameter path: The file path to add.
    private func handleAdd(_ path: String) {
        Task { await appState.addSingle(path: path) }
    } // End of func handleAdd(_:)

    /// Handles the "Apply" action for a file, triggering the confirmation dialog.
    /// - Parameter path: The file path to apply.
    private func handleApply(_ path: String) {
        applyConfirmationPath = path
        showingApplyConfirmation = true
    } // End of func handleApply(_:)

    /// Handles the "Diff" action for a file, loading and presenting the diff viewer.
    /// - Parameter path: The file path to diff.
    private func handleDiff(_ path: String) {
        Task { @MainActor in
            await appState.loadDiff(for: path)
            if let diff = appState.currentDiff {
                diffPayload = DiffPayload(filePath: path, diffText: diff)
            }
        }
    } // End of func handleDiff(_:)

    /// Handles the "Edit" action for a file.
    /// - Parameter path: The file path to open in editor.
    private func handleEdit(_ path: String) {
        appState.openInEditor(path: path)
    } // End of func handleEdit(_:)

    /// Handles the "Merge" action for a file.
    /// - Parameter path: The file path to open in merge tool.
    private func handleMerge(_ path: String) {
        Task { await appState.openInMergeTool(path: path) }
    } // End of func handleMerge(_:)

    /// Handles the "Revert" action for a file, triggering the confirmation dialog.
    /// - Parameter path: The file path to revert.
    private func handleRevert(_ path: String) {
        revertConfirmationPath = path
        showingRevertConfirmation = true
    } // End of func handleRevert(_:)

    /// Handles the "Forget" action for a file, triggering the step 1 confirmation.
    /// - Parameter path: The file path to forget.
    private func handleForget(_ path: String) {
        forgetStep1Path = path
        showingForgetStep1 = true
    } // End of func handleForget(_:)
} // End of struct DashboardView
