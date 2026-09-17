/// Interns extension strings (lowercased, without the leading dot) to `ExtensionID`s.
/// Not thread-safe by itself — callers scanning concurrently intern into their own
/// local `ExtensionTable` and the IDs get remapped when merged into the shared tree
/// (see `FileSystemTree.mergeSubtree`).
public struct ExtensionTable: Sendable {
    private var idsByName: [String: ExtensionID] = [:]
    private var namesByID: [String] = []

    public init() {}

    @discardableResult
    public mutating func intern(_ rawExtension: String?) -> ExtensionID {
        guard let rawExtension, !rawExtension.isEmpty else { return .none }
        let normalized = rawExtension.lowercased()
        if let existing = idsByName[normalized] {
            return existing
        }
        let id = ExtensionID(rawValue: Int32(namesByID.count))
        namesByID.append(normalized)
        idsByName[normalized] = id
        return id
    }

    public func name(for id: ExtensionID) -> String? {
        guard id != .none, id.rawValue >= 0, Int(id.rawValue) < namesByID.count else { return nil }
        return namesByID[Int(id.rawValue)]
    }

    public var allNames: [String] { namesByID }
}

/// Aggregated statistics for a single extension across a scanned tree (or subtree).
public struct ExtensionStats: Sendable, Equatable {
    public let extensionID: ExtensionID
    public let name: String?
    public var fileCount: Int
    public var totalLogical: Int64
    public var totalAllocated: Int64

    public init(extensionID: ExtensionID, name: String?, fileCount: Int = 0, totalLogical: Int64 = 0, totalAllocated: Int64 = 0) {
        self.extensionID = extensionID
        self.name = name
        self.fileCount = fileCount
        self.totalLogical = totalLogical
        self.totalAllocated = totalAllocated
    }
}
