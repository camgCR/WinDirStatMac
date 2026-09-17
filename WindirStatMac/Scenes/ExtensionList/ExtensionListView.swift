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
            TableColumn("Tipo") { stat in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(nsColor: ExtensionColorPalette.color(forExtension: stat.name)))
                        .frame(width: 8, height: 8)
                    Text(stat.name ?? "(sin extensión)")
                        .lineLimit(1)
                }
            }
            TableColumn("Archivos") { stat in
                Text("\(stat.fileCount)")
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("Tamaño") { stat in
                Text(ByteCountFormatter.string(fromByteCount: sizeValue(stat), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            .width(84)
            TableColumn("%") { stat in
                percentageBar(for: stat)
            }
            .width(60)
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
