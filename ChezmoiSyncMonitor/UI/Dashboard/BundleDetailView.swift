import SwiftUI

/// Detail pane showing the member files of a selected bundle.
///
/// Displays a header with the bundle name, member count, and management controls,
/// followed by a scrollable list of member files reusing `FileListItemView`.
struct BundleDetailView: View {

    /// The bundle being displayed.
    let bundle: BundleDefinition

    /// The filtered member files to display (already filtered by the active dashboard filter).
    let filteredMembers: [FileStatus]

    /// Total member count before filtering.
    let totalMemberCount: Int

    /// Whether mutating actions are disabled.
    let isViewOnlyMode: Bool

    // File action callbacks (passed through to FileListItemView)
    let onAdd: (String) -> Void
    let onApply: (String) -> Void
    let onDiff: (String) -> Void
    let onEdit: (String) -> Void
    let onMerge: (String) -> Void
    let onRevert: (String) -> Void
    let onForget: (String) -> Void

    // Bundle management callbacks
    let onRename: () -> Void
    let onDelete: () -> Void
    let onRemoveFromBundle: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            detailHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // File list
            if filteredMembers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredMembers) { file in
                            FileListItemView(
                                file: file,
                                isViewOnlyMode: isViewOnlyMode,
                                onAdd: onAdd,
                                onApply: onApply,
                                onDiff: onDiff,
                                onEdit: onEdit,
                                onMerge: onMerge,
                                onRevert: onRevert,
                                onForget: onForget
                            )
                            .contextMenu {
                                Button(Strings.bundles.removeFromBundle) {
                                    onRemoveFromBundle(file.path)
                                }
                            }

                            if file.id != filteredMembers.last?.id {
                                Divider()
                            }
                        } // End of ForEach over filtered members
                    } // End of LazyVStack
                } // End of ScrollView
            } // End of else (members not empty)

            // Filter hint
            let hiddenCount = totalMemberCount - filteredMembers.count
            if hiddenCount > 0 {
                Text(Strings.bundles.filesHiddenByFilter(hiddenCount))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            }
        } // End of outer VStack
    } // End of body

    /// The header showing bundle name, count, and management buttons.
    private var detailHeader: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(bundle.name)
                .font(.headline)
            Text("(\(totalMemberCount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onRename()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .toolTip(Strings.bundles.renameBundle)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .toolTip(Strings.bundles.deleteBundle)
        } // End of HStack for detail header
    } // End of detailHeader

    /// Empty state when the bundle has no files or all are filtered.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            if totalMemberCount == 0 {
                Text(Strings.bundles.noMembers)
                    .foregroundStyle(.secondary)
            } else {
                Text(Strings.bundles.allMembersFiltered)
                    .foregroundStyle(.secondary)
            }
        } // End of VStack for empty state
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    } // End of emptyState
} // End of struct BundleDetailView
