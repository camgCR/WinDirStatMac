// SPDX-License-Identifier: GPL-2.0-or-later
import DirStatCore

/// One rendered tile of the nested treemap: either a true leaf (file, symlink, or
/// package) or a directory whose contents were too small to subdivide further at
/// the current view size.
struct TreemapTile {
    let id: NodeID
    let rect: TreemapRect
    let node: FileSystemNode
    let extensionName: String?
    let depth: Int
}
