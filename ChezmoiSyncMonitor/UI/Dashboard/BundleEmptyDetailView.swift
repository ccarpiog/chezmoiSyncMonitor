import SwiftUI

/// Empty state shown in the detail pane when no bundle is selected.
struct BundleEmptyDetailView: View {

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(Strings.bundles.selectBundleHint)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } // End of body
} // End of struct BundleEmptyDetailView
