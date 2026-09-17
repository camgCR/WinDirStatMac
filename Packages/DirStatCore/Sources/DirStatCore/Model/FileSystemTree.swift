// SPDX-License-Identifier: GPL-2.0-or-later
/// How to rank nodes for display (tree list order, treemap tile order).
public enum SizeMode: Sendable {
    case logical
    case allocated
}

/// Owns the single shared arena of `FileSystemNode`s for one scan. Scanning workers
/// build isolated `LocalScanResult`s with their own local arenas and extension tables
/// (no shared mutable state, no actor hops per file) and hand them to `mergeChildren`
/// in batches — amortizing actor-hop cost from one-per-file down to one-per-directory
/// (or coarser).
public actor FileSystemTree {
    private var nodes: [FileSystemNode] = []
    private var extensionTable = ExtensionTable()
    public private(set) var rootID: NodeID?
    /// Absolute paths the scan couldn't read into (EACCES/EPERM), typically because
    /// the app lacks Full Disk Access. Populated once by `DirectoryScanner.scan`.
    public private(set) var deniedPaths: [String] = []

    public init() {}

    /// Creates the tree's root node (typically the scanned volume or folder).
    @discardableResult
    public func makeRoot(name: String) -> NodeID {
        let id = NodeID(rawValue: Int32(nodes.count))
        nodes.append(FileSystemNode(parent: nil, name: name, isDirectory: true))
        rootID = id
        return id
    }

    public func node(_ id: NodeID) -> FileSystemNode {
        nodes[Int(id.rawValue)]
    }

    public var nodeCount: Int { nodes.count }

    public func extensionName(for id: ExtensionID) -> String? {
        extensionTable.name(for: id)
    }

    /// Batched lookup — one actor hop for many ids, instead of one per id. Useful
    /// for callers (like the treemap layout) resolving names for a whole batch of
    /// leaf tiles at once.
    public func extensionNames(for ids: [ExtensionID]) -> [ExtensionID: String] {
        var result: [ExtensionID: String] = [:]
        for id in ids {
            if let name = extensionTable.name(for: id) {
                result[id] = name
            }
        }
        return result
    }

    /// Merges a locally-scanned directory's contents in as children of `parentID`,
    /// remapping the local arena's node indices and extension IDs into this tree's
    /// shared arena/extension table. Does not touch ancestor aggregates — call
    /// `finalizeAggregation()` once after all merges for a scan are complete.
    @discardableResult
    func mergeChildren(into parentID: NodeID, result: LocalScanResult) -> [NodeID] {
        let base = Int32(nodes.count)
        func remap(_ localID: LocalNodeID) -> NodeID {
            NodeID(rawValue: base + localID.rawValue)
        }

        var extensionRemap: [ExtensionID: ExtensionID] = [:]
        for (index, name) in result.extensionTable.allNames.enumerated() {
            extensionRemap[ExtensionID(rawValue: Int32(index))] = extensionTable.intern(name)
        }

        for localNode in result.nodes {
            nodes.append(FileSystemNode(
                parent: localNode.parent.map(remap) ?? parentID,
                name: localNode.name,
                extensionID: localNode.extensionID == .none ? .none : (extensionRemap[localNode.extensionID] ?? .none),
                sizeLogical: localNode.sizeLogical,
                sizeAllocated: localNode.sizeAllocated,
                isDirectory: localNode.isDirectory,
                isPackage: localNode.isPackage,
                isSymlink: localNode.isSymlink,
                permissionDenied: localNode.permissionDenied,
                isMountPoint: localNode.isMountPoint,
                children: localNode.children.map(remap)
            ))
        }

        let newTopLevel = result.topLevelChildren.map(remap)
        nodes[Int(parentID.rawValue)].children.append(contentsOf: newTopLevel)
        nodes[Int(parentID.rawValue)].childrenSortedCache = nil
        return newTopLevel
    }

    func recordDeniedPaths(_ paths: [String]) {
        deniedPaths = paths
    }

    /// Full bottom-up rollup of `aggregateLogical`/`aggregateAllocated` for every
    /// directory in the tree. Call once after all subtrees have been merged.
    public func finalizeAggregation() {
        guard let rootID else { return }
        SizeAggregator.aggregate(nodes: &nodes, root: rootID)
    }

    /// Children of `id`, sorted descending by the given size mode. Computes and
    /// caches the sort order on first access; the cache is invalidated by any
    /// merge into this node.
    public func children(of id: NodeID, sortedBy mode: SizeMode) -> [NodeID] {
        var parentNode = nodes[Int(id.rawValue)]
        if let cached = parentNode.childrenSortedCache {
            return cached
        }
        let sorted = parentNode.children.sorted(by: NodeSortComparator.bySize(mode: mode, in: nodes))
        parentNode.childrenSortedCache = sorted
        nodes[Int(id.rawValue)] = parentNode
        return sorted
    }

    /// Extension stats aggregated across the whole tree.
    public func extensionStats() -> [ExtensionStats] {
        ExtensionAggregator.aggregate(nodes: nodes, extensionTable: extensionTable)
    }

    /// Detaches `id` from its parent (after the corresponding file/directory has
    /// actually been deleted on disk) and subtracts its size from every ancestor,
    /// without a full rescan. Returns the parent's id, or `nil` if `id` is the root
    /// (which can't be removed this way) or already detached. The node's own arena
    /// slot is left in place — it becomes unreachable from the root, not reclaimed —
    /// so no other `NodeID` is invalidated by this call.
    @discardableResult
    public func removeFromTree(_ id: NodeID) -> NodeID? {
        guard Int(id.rawValue) < nodes.count, let parentID = nodes[Int(id.rawValue)].parent else { return nil }
        let removed = nodes[Int(id.rawValue)]
        nodes[Int(id.rawValue)].isDeleted = true

        nodes[Int(parentID.rawValue)].children.removeAll { $0 == id }
        nodes[Int(parentID.rawValue)].childrenSortedCache?.removeAll { $0 == id }

        SizeAggregator.propagateDelta(
            nodes: &nodes,
            from: parentID,
            logicalDelta: -removed.aggregateLogical,
            allocatedDelta: -removed.aggregateAllocated
        )
        return parentID
    }

    /// Case-insensitive substring search over every node's name, sorted
    /// descending by size. Excludes anything already removed via
    /// `removeFromTree`.
    public func search(query: String, sizeMode: SizeMode) -> [SearchResult] {
        SearchEngine.search(nodes: nodes, query: query, sizeMode: sizeMode)
    }

    /// Every node in the tree (excluding anything removed via `removeFromTree`)
    /// as a flat list of `CSVRow`s, each carrying its path relative to the scan
    /// root. Depth-first, so a directory's row always precedes its children's.
    public func exportRows() -> [CSVRow] {
        guard let rootID else { return [] }
        var rows: [CSVRow] = []
        appendRows(for: rootID, parentPath: "", into: &rows)
        return rows
    }

    private func appendRows(for id: NodeID, parentPath: String, into rows: inout [CSVRow]) {
        let node = nodes[Int(id.rawValue)]
        guard !node.isDeleted else { return }

        let path = parentPath.isEmpty ? node.name : parentPath + "/" + node.name
        rows.append(CSVRow(
            path: path,
            name: node.name,
            type: entryType(for: node),
            sizeLogical: node.aggregateLogical,
            sizeAllocated: node.aggregateAllocated,
            extensionName: extensionTable.name(for: node.extensionID)
        ))

        for childID in node.children {
            appendRows(for: childID, parentPath: path, into: &rows)
        }
    }

    private func entryType(for node: FileSystemNode) -> CSVEntryType {
        if node.permissionDenied { return .permissionDenied }
        if node.isMountPoint { return .mountPoint }
        if node.isPackage { return .package }
        if node.isSymlink { return .symlink }
        return node.isDirectory ? .directory : .file
    }
}
