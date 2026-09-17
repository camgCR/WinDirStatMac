// SPDX-License-Identifier: GPL-2.0-or-later
/// One match from `FileSystemTree.search`.
public struct SearchResult: Sendable, Identifiable, Equatable {
    public let id: NodeID
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let aggregateLogical: Int64
    public let aggregateAllocated: Int64

    public init(id: NodeID, name: String, isDirectory: Bool, isPackage: Bool, aggregateLogical: Int64, aggregateAllocated: Int64) {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.aggregateLogical = aggregateLogical
        self.aggregateAllocated = aggregateAllocated
    }
}
