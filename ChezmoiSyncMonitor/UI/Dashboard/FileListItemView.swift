import SwiftUI

/// A reusable row view for displaying a single file's sync status and available actions.
///
/// Shows a status color indicator, file path, state label, and contextual action
/// buttons based on the file's available actions.
struct FileListItemView: View {

    /// The file status to display.
    let file: FileStatus

    /// Whether mutating actions should be disabled (view-only mode).
    let isViewOnlyMode: Bool

    /// Callback invoked when the user taps the "Add" button (syncLocal action).
    let onAdd: (String) -> Void

    /// Callback invoked when the user taps the "Apply" button (applyRemote action).
    let onApply: (String) -> Void

    /// Callback invoked when the user taps the "Diff" button (viewDiff action).
    let onDiff: (String) -> Void

    /// Callback invoked when the user taps the "Edit" button (openEditor action).
    let onEdit: (String) -> Void

    /// Callback invoked when the user taps the "Merge" button (openMergeTool action).
    let onMerge: (String) -> Void

    /// Callback invoked when the user taps the "Revert" button (revertLocal action).
    let onRevert: (String) -> Void

    /// Callback invoked when the user taps the "Forget" button (forgetFile action).
    let onForget: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Status color indicator
            Circle()
                .fill(file.state.color)
                .frame(width: 10, height: 10)

            // File path
            Text(file.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            // State label
            Text(file.state.displayName)
                .font(.caption)
                .foregroundStyle(file.state.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(file.state.color.opacity(0.12))
                )

            // Action buttons
            actionButtons
        } // End of HStack for file row
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    } // End of body

    /// Builds the action buttons based on the file's available actions.
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            if file.availableActions.contains(.syncLocal) {
                Button(Strings.fileActions.add) {
                    onAdd(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .toolTip(Strings.fileActions.addHint)
            }

            if file.availableActions.contains(.applyRemote) {
                Button(Strings.fileActions.apply) {
                    onApply(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .toolTip(Strings.fileActions.applyHint)
            }

            if file.availableActions.contains(.viewDiff) {
                Button(Strings.fileActions.diff) {
                    onDiff(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .toolTip(Strings.fileActions.diffHint)
            }

            if file.availableActions.contains(.openEditor) {
                Button(Strings.fileActions.edit) {
                    onEdit(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .toolTip(Strings.fileActions.editHint)
            }

            if file.availableActions.contains(.openMergeTool) {
                Button(Strings.fileActions.merge) {
                    onMerge(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .toolTip(Strings.fileActions.mergeHint)
            }

            if file.availableActions.contains(.revertLocal) {
                Button(Strings.fileActions.revert) {
                    onRevert(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .toolTip(Strings.fileActions.revertHint)
            }

            if file.availableActions.contains(.forgetFile) {
                Button(Strings.fileActions.forget) {
                    onForget(file.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isViewOnlyMode)
                .foregroundStyle(.red)
                .toolTip(Strings.fileActions.forgetHint)
            }
        } // End of HStack for action buttons
    } // End of actionButtons
} // End of struct FileListItemView
