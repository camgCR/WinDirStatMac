// SPDX-License-Identifier: GPL-2.0-or-later
import DirStatCore

/// Recursively lays out an entire scanned subtree into nested tiles — this is what
/// makes the view a real "treemap" (multiple directory levels visible at once)
/// rather than just a one-level chart of the current folder's children. Recursion
/// stops at true leaves or once a rect's area drops below `minTileArea`, which
/// bounds both the number of tiles drawn and the number of actor round-trips this
/// takes on a very large tree.
enum TreemapLayoutEngine {
    @MainActor
    static func buildTiles(rootID: NodeID, bounds: TreemapRect, minTileArea: Double, viewModel: ScanViewModel) async -> [TreemapTile] {
        guard let node = await viewModel.node(rootID) else { return [] }
        return await buildTiles(rootID: rootID, node: node, bounds: bounds, minTileArea: minTileArea, viewModel: viewModel)
    }

    /// `node` is passed in (rather than re-fetched here) whenever the caller
    /// already has it — building `layoutItems` below requires fetching every
    /// child's own node anyway, so handing that same value back for that child
    /// avoids a second, redundant actor round-trip per node.
    @MainActor
    private static func buildTiles(rootID: NodeID, node: FileSystemNode, bounds: TreemapRect, minTileArea: Double, viewModel: ScanViewModel) async -> [TreemapTile] {
        guard bounds.width > 0, bounds.height > 0 else { return [] }

        guard canExpand(node, bounds: bounds, minTileArea: minTileArea) else {
            let extName = await viewModel.extensionName(for: node.extensionID)
            return [TreemapTile(id: rootID, rect: bounds, node: node, extensionName: extName, depth: 0)]
        }

        let childIDs = await viewModel.children(of: rootID)
        guard !childIDs.isEmpty else {
            let extName = await viewModel.extensionName(for: node.extensionID)
            return [TreemapTile(id: rootID, rect: bounds, node: node, extensionName: extName, depth: 0)]
        }

        var layoutItems: [TreemapLayoutNode] = []
        var childNodes: [NodeID: FileSystemNode] = [:]
        layoutItems.reserveCapacity(childIDs.count)
        for childID in childIDs {
            guard let childNode = await viewModel.node(childID) else { continue }
            childNodes[childID] = childNode
            let weight = viewModel.sizeMode == .logical ? childNode.aggregateLogical : childNode.aggregateAllocated
            guard weight > 0 else { continue }
            layoutItems.append(TreemapLayoutNode(id: childID, weight: Double(weight)))
        }

        // A directory can have real children that are all zero-weight — most
        // commonly a folder whose entire contents are permission-denied (each
        // recorded with size 0) without Full Disk Access. Squarified layout can't
        // place zero-weight items, so without this fallback the whole rect would
        // just render as unfilled background instead of showing *something*.
        guard !layoutItems.isEmpty else {
            let extName = await viewModel.extensionName(for: node.extensionID)
            return [TreemapTile(id: rootID, rect: bounds, node: node, extensionName: extName, depth: 0)]
        }

        let childLayout = SquarifiedTreemapLayout.layout(items: layoutItems, in: bounds)

        // Most children in a real directory turn out to be immediate leaves (an
        // ordinary file, or a subfolder too small to subdivide further at this
        // view size) — split those out and resolve all their extension names in
        // one batched actor call, instead of one recursive call (and one
        // extension-name fetch) per file. Only children that actually need
        // further subdivision fall through to a real recursive call.
        var leafChildren: [(id: NodeID, rect: TreemapRect, node: FileSystemNode)] = []
        var expandChildren: [(id: NodeID, rect: TreemapRect, node: FileSystemNode)] = []
        for childID in childIDs {
            guard let rect = childLayout[childID], rect.area > 0, let childNode = childNodes[childID] else { continue }
            if canExpand(childNode, bounds: rect, minTileArea: minTileArea) {
                expandChildren.append((childID, rect, childNode))
            } else {
                leafChildren.append((childID, rect, childNode))
            }
        }

        var tiles: [TreemapTile] = []
        tiles.reserveCapacity(leafChildren.count + expandChildren.count)

        if !leafChildren.isEmpty {
            let extensionNames = await viewModel.extensionNames(for: leafChildren.map(\.node.extensionID))
            for leaf in leafChildren {
                tiles.append(TreemapTile(id: leaf.id, rect: leaf.rect, node: leaf.node, extensionName: extensionNames[leaf.node.extensionID], depth: 1))
            }
        }

        for child in expandChildren {
            let subtiles = await buildTiles(rootID: child.id, node: child.node, bounds: child.rect, minTileArea: minTileArea, viewModel: viewModel)
            tiles.append(contentsOf: subtiles.map { tile in
                TreemapTile(id: tile.id, rect: tile.rect, node: tile.node, extensionName: tile.extensionName, depth: tile.depth + 1)
            })
        }

        return tiles
    }

    private static func canExpand(_ node: FileSystemNode, bounds: TreemapRect, minTileArea: Double) -> Bool {
        node.isDirectory && !node.isPackage && !node.children.isEmpty && bounds.area >= minTileArea
    }
}
