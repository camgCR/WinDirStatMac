import SwiftUI
import DirStatCore

/// A thin status line under the treemap describing whatever's under the cursor
/// (falling back to the current selection), since individual tiles are often too
/// small to hold a readable label.
struct TreemapInfoBar: View {
    var viewModel: ScanViewModel
    @State private var text: String = " "

    private var focusedID: NodeID? { viewModel.hoveredNodeID ?? viewModel.selectedNodeID }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .task(id: focusedID) {
                text = await describe(focusedID)
            }
    }

    private func describe(_ id: NodeID?) async -> String {
        guard let id, let node = await viewModel.node(id) else { return " " }
        let size = viewModel.sizeMode == .logical ? node.aggregateLogical : node.aggregateAllocated
        let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        return "\(node.name) — \(sizeString)"
    }
}
