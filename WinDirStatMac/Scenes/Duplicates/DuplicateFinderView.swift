// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import DirStatCore

struct DuplicateFinderView: View {
    var viewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [DuplicateGroup] = []
    @State private var isScanning = true
    @State private var didScanOnce = false
    @State private var progress = DuplicateScanProgress.Snapshot(phase: 1, processed: 0, total: 0)

    private var wastedBytes: Int64 {
        groups.reduce(0) { $0 + $1.size * Int64($1.nodeIDs.count - 1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isScanning {
                VStack(spacing: 12) {
                    if progress.total > 0 {
                        ProgressView(value: Double(progress.processed), total: Double(progress.total))
                            .frame(width: 240)
                    } else {
                        ProgressView()
                    }
                    Text(progressText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView(loc("No Duplicates Found"), systemImage: "checkmark.circle")
            } else {
                List {
                    ForEach(groups) { group in
                        DuplicateGroupSection(group: group, viewModel: viewModel) { removedID in
                            remove(removedID, from: group)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 640, height: 480)
        .task {
            groups = await viewModel.findDuplicates { snapshot in
                progress = snapshot
            }
            isScanning = false
            didScanOnce = true
        }
    }

    private var progressText: String {
        guard progress.total > 0 else { return loc("Looking for same-size files…") }
        let phaseLabel = progress.phase == 1 ? loc("Quick filter") : loc("Confirming matches")
        return "\(phaseLabel): \(progress.processed) / \(progress.total) \(loc("files analyzed"))"
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc("Duplicate Files"))
                    .font(.headline)
                if didScanOnce, !groups.isEmpty {
                    Text("\(groups.count) \(loc("groups")) — \(loc("could free up")) \(ByteCountFormatter.string(fromByteCount: wastedBytes, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(isScanning ? loc("Cancel") : loc("Done")) { dismiss() }
        }
        .padding(12)
    }

    private func remove(_ id: NodeID, from group: DuplicateGroup) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == group.id }) else { return }
        var remaining = groups[groupIndex].nodeIDs
        remaining.removeAll { $0 == id }
        if remaining.count < 2 {
            groups.remove(at: groupIndex)
        } else {
            groups[groupIndex] = DuplicateGroup(id: group.id, size: group.size, nodeIDs: remaining)
        }
    }
}

private struct DuplicateGroupSection: View {
    let group: DuplicateGroup
    var viewModel: ScanViewModel
    let onRemove: (NodeID) -> Void

    var body: some View {
        Section {
            ForEach(group.nodeIDs, id: \.self) { id in
                DuplicateFileRow(id: id, viewModel: viewModel, onRemove: { onRemove(id) })
            }
        } header: {
            Text("\(group.nodeIDs.count) × \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file))")
        }
    }
}

private struct DuplicateFileRow: View {
    let id: NodeID
    var viewModel: ScanViewModel
    let onRemove: () -> Void
    @State private var path: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
            Text(path ?? "…")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                Task { await viewModel.revealInFinder(id) }
            } label: {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.plain)
            .help(loc("Reveal in Finder"))
            Button {
                Task {
                    viewModel.lastErrorMessage = nil
                    await viewModel.moveToTrash(id)
                    if viewModel.lastErrorMessage == nil {
                        onRemove()
                    }
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help(loc("Move to Trash"))
        }
        .task {
            path = await viewModel.fullPath(of: id)
        }
    }
}
