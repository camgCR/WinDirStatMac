// SPDX-License-Identifier: GPL-2.0-or-later
/// Aggregates per-extension file counts/sizes across a scanned tree. Directories
/// (including package/bundle leaf nodes, which carry no extension) are excluded —
/// this reflects actual file extensions only, same as the tree list's file rows.
enum ExtensionAggregator {
    static func aggregate(nodes: [FileSystemNode], extensionTable: ExtensionTable) -> [ExtensionStats] {
        var statsByID: [ExtensionID: ExtensionStats] = [:]
        for node in nodes where !node.isDirectory {
            var stats = statsByID[node.extensionID] ?? ExtensionStats(extensionID: node.extensionID, name: extensionTable.name(for: node.extensionID))
            stats.fileCount += 1
            stats.totalLogical += node.sizeLogical
            stats.totalAllocated += node.sizeAllocated
            statsByID[node.extensionID] = stats
        }
        return statsByID.values.sorted { $0.totalAllocated > $1.totalAllocated }
    }
}
