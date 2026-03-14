import SwiftUI
import UniformTypeIdentifiers

/// A row view displaying a bundle's name, member count, aggregate state, and compact state tags.
///
/// Used in the main pane of the dashboard two-pane layout. Tapping selects the bundle
/// to show its members in the detail pane. Supports drop targets for file drag-and-drop.
struct BundleRowView: View {

    /// The bundle to display.
    let bundle: BundleDefinition

    /// The worst state among the bundle's members.
    let aggregateState: FileSyncState

    /// Per-state counts for compact tags.
    let stateCounts: [FileSyncState: Int]

    /// Total resolved member count (members that exist in the current snapshot).
    let resolvedMemberCount: Int

    /// Whether this bundle row is currently selected.
    let isSelected: Bool

    /// Callback invoked when file paths are dropped onto this bundle.
    var onDropPaths: (([String]) -> Void)?

    /// Whether a drag is currently hovering over this row.
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            // Folder icon with aggregate state color
            Image(systemName: isDropTargeted ? "folder.fill.badge.plus" : "folder.fill")
                .foregroundStyle(isDropTargeted ? .accentColor : aggregateState.color)
                .font(.title3)

            // Bundle name (bold to distinguish from file rows)
            VStack(alignment: .leading, spacing: 2) {
                Text(bundle.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(Strings.bundles.memberCount(resolvedMemberCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Compact state count tags (only non-clean states)
            stateCountTags
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear))
        )
        .contentShape(Rectangle())
        .onDrop(of: [UTType.plainText], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    } // End of body

    /// Processes dropped items, extracting file paths and invoking the callback.
    /// - Parameter providers: The drop item providers.
    /// - Returns: Whether the drop was accepted.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard onDropPaths != nil else { return false }
        let lock = NSLock()
        var paths: [String] = []
        let group = DispatchGroup()
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                group.enter()
                _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let path = item as? String {
                        lock.lock()
                        paths.append(path)
                        lock.unlock()
                    }
                    group.leave()
                } // End of loadObject callback
            }
        } // End of for loop over providers
        group.notify(queue: .main) {
            if !paths.isEmpty {
                onDropPaths?(paths)
            }
        }
        return true
    } // End of func handleDrop(providers:)

    /// Compact colored capsule tags showing counts for each non-clean state.
    @ViewBuilder
    private var stateCountTags: some View {
        HStack(spacing: 4) {
            // Show tags in state precedence order
            ForEach([FileSyncState.localDrift, .remoteDrift, .dualDrift, .error], id: \.self) { state in
                if let count = stateCounts[state], count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(state.color)
                        )
                }
            } // End of ForEach over state tags
        } // End of HStack for state tags
    } // End of stateCountTags
} // End of struct BundleRowView
