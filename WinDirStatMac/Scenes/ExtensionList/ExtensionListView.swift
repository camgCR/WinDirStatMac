// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import DirStatCore

/// Per-extension breakdown of the current scan, shared color-coding with the
/// treemap tiles via `ExtensionColorPalette` so the same extension reads the same
/// way in both views.
struct ExtensionListView: View {
    var viewModel: ScanViewModel
    @State private var stats: [ExtensionStats] = []

    private func sizeValue(_ stat: ExtensionStats) -> Int64 {
        viewModel.sizeMode == .logical ? stat.totalLogical : stat.totalAllocated
    }

    private var sortedStats: [ExtensionStats] {
        stats.sorted { sizeValue($0) > sizeValue($1) }
    }

    private var totalSize: Int64 {
        stats.reduce(0) { $0 + sizeValue($1) }
    }

    var body: some View {
        Table(sortedStats) {
            TableColumn(loc("Type")) { stat in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(nsColor: ExtensionColorPalette.color(forExtension: stat.name)))
                        .frame(width: 8, height: 8)
                    Text(stat.name ?? loc("(no extension)"))
                        .lineLimit(1)
                }
            }
            .width(min: 70, ideal: 110)
            TableColumn(loc("Files")) { stat in
                Text("\(stat.fileCount)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .width(min: 40, ideal: 50, max: 64)
            TableColumn(loc("Size")) { stat in
                Text(ByteCountFormatter.string(fromByteCount: sizeValue(stat), countStyle: .file))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .width(min: 56, ideal: 72, max: 90)
            TableColumn("%") { stat in
                percentageBar(for: stat)
            }
            .width(min: 32, ideal: 40, max: 52)
        }
        .task(id: viewModel.rootID) {
            stats = await viewModel.extensionStats()
        }
    }

    private func percentageBar(for stat: ExtensionStats) -> some View {
        let fraction = totalSize > 0 ? Double(sizeValue(stat)) / Double(totalSize) : 0
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color(nsColor: ExtensionColorPalette.color(forExtension: stat.name)))
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 10)
    }
}
