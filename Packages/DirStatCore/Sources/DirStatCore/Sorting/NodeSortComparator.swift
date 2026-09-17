// SPDX-License-Identifier: GPL-2.0-or-later
enum NodeSortComparator {
    /// Descending comparator by aggregate size in the given mode, for sorting a
    /// directory's children (largest first, matching the original app and Finder's
    /// "Size" column convention).
    static func bySize(mode: SizeMode, in nodes: [FileSystemNode]) -> (NodeID, NodeID) -> Bool {
        { lhs, rhs in
            let lhsValue = value(of: lhs, mode: mode, in: nodes)
            let rhsValue = value(of: rhs, mode: mode, in: nodes)
            return lhsValue > rhsValue
        }
    }

    private static func value(of id: NodeID, mode: SizeMode, in nodes: [FileSystemNode]) -> Int64 {
        let node = nodes[Int(id.rawValue)]
        return mode == .logical ? node.aggregateLogical : node.aggregateAllocated
    }
}
