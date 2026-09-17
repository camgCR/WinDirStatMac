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
        guard bounds.width > 0, bounds.height > 0, let node = await viewModel.node(rootID) else { return [] }

        let canExpand = node.isDirectory && !node.isPackage && !node.children.isEmpty && bounds.area >= minTileArea
        guard canExpand else {
            let extName = await viewModel.extensionName(for: node.extensionID)
            return [TreemapTile(id: rootID, rect: bounds, node: node, extensionName: extName, depth: 0)]
        }

        let childIDs = await viewModel.children(of: rootID)
        guard !childIDs.isEmpty else {
            let extName = await viewModel.extensionName(for: node.extensionID)
            return [TreemapTile(id: rootID, rect: bounds, node: node, extensionName: extName, depth: 0)]
        }

        var layoutItems: [TreemapLayoutNode] = []
        layoutItems.reserveCapacity(childIDs.count)
        for childID in childIDs {
            guard let childNode = await viewModel.node(childID) else { continue }
            let weight = viewModel.sizeMode == .logical ? childNode.aggregateLogical : childNode.aggregateAllocated
            guard weight > 0 else { continue }
            layoutItems.append(TreemapLayoutNode(id: childID, weight: Double(weight)))
        }

        let childLayout = SquarifiedTreemapLayout.layout(items: layoutItems, in: bounds)
        var tiles: [TreemapTile] = []
        for childID in childIDs {
            guard let rect = childLayout[childID], rect.area >= 1 else { continue }
            let subtiles = await buildTiles(rootID: childID, bounds: rect, minTileArea: minTileArea, viewModel: viewModel)
            tiles.append(contentsOf: subtiles.map { tile in
                TreemapTile(id: tile.id, rect: tile.rect, node: tile.node, extensionName: tile.extensionName, depth: tile.depth + 1)
            })
        }
        return tiles
    }
}
