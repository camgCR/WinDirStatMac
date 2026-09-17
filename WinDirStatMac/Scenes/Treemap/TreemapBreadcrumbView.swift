// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import DirStatCore

/// Shows the path from the scan root to the current treemap zoom root, letting
/// the user jump back up to any ancestor level instead of only one step at a time.
struct TreemapBreadcrumbView: View {
    var viewModel: ScanViewModel
    @State private var chain: [(id: NodeID, name: String)] = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(chain.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button(entry.name) {
                        viewModel.setZoomRoot(entry.id)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(index == chain.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .task(id: viewModel.zoomRootID) {
            chain = await viewModel.breadcrumbPath()
        }
    }
}
