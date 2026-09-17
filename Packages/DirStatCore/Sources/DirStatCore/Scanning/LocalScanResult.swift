// SPDX-License-Identifier: GPL-2.0-or-later
/// Index into a `LocalScanResult`'s private arena — distinct from `NodeID` (which
/// indexes the shared `FileSystemTree` arena) so the two can never be confused.
struct LocalNodeID: Hashable, Sendable {
    let rawValue: Int32
}

/// A node as seen by a single scan worker, before being merged into the shared
/// `FileSystemTree`. `parent == nil` means "the parent is whatever node this
/// `LocalScanResult` gets merged into" — only true top-level entries of the scanned
/// directory have a nil parent; deeper descendants point at their local ancestor.
struct LocalNode: Sendable {
    var parent: LocalNodeID?
    var children: [LocalNodeID]
    var name: String
    var extensionID: ExtensionID
    var sizeLogical: Int64
    var sizeAllocated: Int64
    var isDirectory: Bool
    var isPackage: Bool
    var isSymlink: Bool
    var permissionDenied: Bool
    var isMountPoint: Bool
}

/// The result of scanning one directory's contents (not including a node for the
/// directory itself — the caller, which already knows this directory's own name/
/// stat, creates that node when merging this result into its own).
struct LocalScanResult: Sendable {
    var nodes: [LocalNode] = []
    var topLevelChildren: [LocalNodeID] = []
    var extensionTable = ExtensionTable()
    var deniedPaths: [String] = []
    var scannedFileCount: Int = 0
    /// Recursive sum of every leaf's size within this result, tracked incrementally
    /// so a package/bundle directory's total size is available in O(1) rather than
    /// requiring a second traversal pass.
    var totalLogical: Int64 = 0
    var totalAllocated: Int64 = 0

    mutating func addLeaf(name: String, extensionID: ExtensionID, sizeLogical: Int64, sizeAllocated: Int64, isSymlink: Bool) {
        let id = LocalNodeID(rawValue: Int32(nodes.count))
        nodes.append(LocalNode(
            parent: nil, children: [], name: name, extensionID: extensionID,
            sizeLogical: sizeLogical, sizeAllocated: sizeAllocated,
            isDirectory: false, isPackage: false, isSymlink: isSymlink, permissionDenied: false, isMountPoint: false
        ))
        topLevelChildren.append(id)
        scannedFileCount += 1
        totalLogical += sizeLogical
        totalAllocated += sizeAllocated
    }

    mutating func addPermissionDeniedDirectory(name: String, path: String) {
        let id = LocalNodeID(rawValue: Int32(nodes.count))
        nodes.append(LocalNode(
            parent: nil, children: [], name: name, extensionID: .none,
            sizeLogical: 0, sizeAllocated: 0,
            isDirectory: true, isPackage: false, isSymlink: false, permissionDenied: true, isMountPoint: false
        ))
        topLevelChildren.append(id)
        deniedPaths.append(path)
    }

    /// Records a directory that's a mount point for a different filesystem than
    /// its parent, without descending into it — see `FileSystemNode.isMountPoint`
    /// for why crossing it would corrupt the size totals.
    mutating func addMountPoint(name: String, sizeLogical: Int64, sizeAllocated: Int64) {
        let id = LocalNodeID(rawValue: Int32(nodes.count))
        nodes.append(LocalNode(
            parent: nil, children: [], name: name, extensionID: .none,
            sizeLogical: sizeLogical, sizeAllocated: sizeAllocated,
            isDirectory: true, isPackage: false, isSymlink: false, permissionDenied: false, isMountPoint: true
        ))
        topLevelChildren.append(id)
        scannedFileCount += 1
        totalLogical += sizeLogical
        totalAllocated += sizeAllocated
    }

    /// Merges an already-scanned subdirectory's contents in as a new top-level
    /// directory node named `name`. If `asPackage` is true, the subdirectory's
    /// contents are collapsed into a single opaque leaf sized by their total.
    mutating func addDirectory(name: String, childResult: LocalScanResult, asPackage: Bool) {
        scannedFileCount += childResult.scannedFileCount
        deniedPaths.append(contentsOf: childResult.deniedPaths)
        totalLogical += childResult.totalLogical
        totalAllocated += childResult.totalAllocated

        if asPackage {
            let id = LocalNodeID(rawValue: Int32(nodes.count))
            nodes.append(LocalNode(
                parent: nil, children: [], name: name, extensionID: .none,
                sizeLogical: childResult.totalLogical, sizeAllocated: childResult.totalAllocated,
                isDirectory: true, isPackage: true, isSymlink: false, permissionDenied: false, isMountPoint: false
            ))
            topLevelChildren.append(id)
            return
        }

        // Remap the child arena's extension IDs into this arena's extension table.
        var extensionRemap: [ExtensionID: ExtensionID] = [:]
        for (index, extName) in childResult.extensionTable.allNames.enumerated() {
            extensionRemap[ExtensionID(rawValue: Int32(index))] = extensionTable.intern(extName)
        }

        // Append the directory node itself first (as a placeholder), then its
        // remapped descendants — so index arithmetic below matches append order
        // exactly instead of relying on a later `insert` (which would also be O(n)).
        let dirID = LocalNodeID(rawValue: Int32(nodes.count))
        nodes.append(LocalNode(
            parent: nil, children: [], name: name, extensionID: .none,
            sizeLogical: 0, sizeAllocated: 0,
            isDirectory: true, isPackage: false, isSymlink: false, permissionDenied: false, isMountPoint: false
        ))
        let base = Int32(nodes.count)

        for var childNode in childResult.nodes {
            childNode.parent = childNode.parent.map { LocalNodeID(rawValue: base + $0.rawValue) } ?? dirID
            childNode.children = childNode.children.map { LocalNodeID(rawValue: base + $0.rawValue) }
            if childNode.extensionID != .none {
                childNode.extensionID = extensionRemap[childNode.extensionID] ?? .none
            }
            nodes.append(childNode)
        }

        nodes[Int(dirID.rawValue)].children = childResult.topLevelChildren.map { LocalNodeID(rawValue: base + $0.rawValue) }
        topLevelChildren.append(dirID)
    }
}
