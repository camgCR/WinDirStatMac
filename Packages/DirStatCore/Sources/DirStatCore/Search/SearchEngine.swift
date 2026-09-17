// SPDX-License-Identifier: GPL-2.0-or-later
/// Case-insensitive substring match over every node's own name — pure and
/// UI-free so it's directly unit-testable, and cheap enough (simple string
/// scan, no regex) to run as a single pass over a 500k-node arena on demand
/// rather than needing a persistent index.
enum SearchEngine {
    static func search(nodes: [FileSystemNode], query: String, sizeMode: SizeMode) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.lowercased()

        var results: [SearchResult] = []
        for index in nodes.indices {
            let node = nodes[index]
            guard !node.isDeleted, node.name.lowercased().contains(needle) else { continue }
            results.append(SearchResult(
                id: NodeID(rawValue: Int32(index)),
                name: node.name,
                isDirectory: node.isDirectory,
                isPackage: node.isPackage,
                aggregateLogical: node.aggregateLogical,
                aggregateAllocated: node.aggregateAllocated
            ))
        }

        results.sort { lhs, rhs in
            let lhsSize = sizeMode == .logical ? lhs.aggregateLogical : lhs.aggregateAllocated
            let rhsSize = sizeMode == .logical ? rhs.aggregateLogical : rhs.aggregateAllocated
            return lhsSize > rhsSize
        }
        return results
    }
}
