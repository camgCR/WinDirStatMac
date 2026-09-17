/// Interned identifier for a file extension (or the "no extension" bucket), stable
/// within a single `FileSystemTree`. Interning avoids storing/copying the extension
/// string on every one of the (potentially 500k+) nodes.
public struct ExtensionID: Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Sentinel for files with no extension (or directories, which have none).
    public static let none = ExtensionID(rawValue: -1)
}

/// A single file, directory, or symlink in the scan tree.
///
/// `children` is populated exactly once, when a fully-scanned subtree is merged
/// into its parent (see `FileSystemTree.mergeSubtree`) — it is never appended to
/// incrementally element-by-element, so there's no repeated array growth on the
/// scanning hot path.
public struct FileSystemNode: Sendable {
    public var parent: NodeID?
    public var children: [NodeID]
    public var name: String
    public var extensionID: ExtensionID

    /// Logical size (`st_size`) — for directories, 0 until aggregated.
    public var sizeLogical: Int64
    /// Allocated size on disk (`st_blocks * 512`) — for directories, 0 until aggregated.
    public var sizeAllocated: Int64

    /// Rollup of `sizeLogical` across the subtree rooted at this node (== sizeLogical for files).
    public var aggregateLogical: Int64
    /// Rollup of `sizeAllocated` across the subtree rooted at this node (== sizeAllocated for files).
    public var aggregateAllocated: Int64

    public var isDirectory: Bool
    /// True for directories macOS treats as opaque bundles (.app, .bundle, .framework, ...)
    /// when `ScanOptions.treatPackagesAsFiles` is enabled.
    public var isPackage: Bool
    public var isSymlink: Bool
    /// Set when enumerating this node's contents failed with EACCES/EPERM.
    /// The node itself is still recorded; its subtree is simply empty.
    public var permissionDenied: Bool

    /// Children sorted by `aggregateAllocated`/`aggregateLogical` descending, computed lazily
    /// and invalidated whenever children or the active size mode changes.
    public var childrenSortedCache: [NodeID]?

    public init(
        parent: NodeID?,
        name: String,
        extensionID: ExtensionID = .none,
        sizeLogical: Int64 = 0,
        sizeAllocated: Int64 = 0,
        isDirectory: Bool = false,
        isPackage: Bool = false,
        isSymlink: Bool = false,
        permissionDenied: Bool = false,
        children: [NodeID] = []
    ) {
        self.parent = parent
        self.children = children
        self.name = name
        self.extensionID = extensionID
        self.sizeLogical = sizeLogical
        self.sizeAllocated = sizeAllocated
        self.aggregateLogical = sizeLogical
        self.aggregateAllocated = sizeAllocated
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isSymlink = isSymlink
        self.permissionDenied = permissionDenied
        self.childrenSortedCache = nil
    }
}
