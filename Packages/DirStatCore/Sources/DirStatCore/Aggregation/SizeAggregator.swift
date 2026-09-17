/// Bottom-up rollup of directory sizes from their children. Pure and UI-free so it
/// can be exercised directly against synthetic arenas in unit tests.
///
/// Recurses once per tree level; real-world filesystem hierarchies are shallow
/// enough (a few hundred levels at the pathological extreme) that this is safe,
/// but a maliciously/synthetically deep tree could exhaust the call stack — a known
/// limitation shared with the recursive scan itself, not addressed in v1.
enum SizeAggregator {
    static func aggregate(nodes: inout [FileSystemNode], root: NodeID) {
        _ = aggregateSubtree(nodes: &nodes, id: root)
    }

    @discardableResult
    private static func aggregateSubtree(nodes: inout [FileSystemNode], id: NodeID) -> (logical: Int64, allocated: Int64) {
        let children = nodes[Int(id.rawValue)].children
        guard !children.isEmpty else {
            let node = nodes[Int(id.rawValue)]
            return (node.aggregateLogical, node.aggregateAllocated)
        }

        var totalLogical: Int64 = 0
        var totalAllocated: Int64 = 0
        for childID in children {
            let (childLogical, childAllocated) = aggregateSubtree(nodes: &nodes, id: childID)
            totalLogical += childLogical
            totalAllocated += childAllocated
        }

        nodes[Int(id.rawValue)].aggregateLogical = totalLogical
        nodes[Int(id.rawValue)].aggregateAllocated = totalAllocated
        return (totalLogical, totalAllocated)
    }
}
