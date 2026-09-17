// SPDX-License-Identifier: GPL-2.0-or-later
/// A set of files confirmed byte-identical (same size, same content hash).
public struct DuplicateGroup: Sendable, Identifiable, Equatable {
    public let id: String
    public let size: Int64
    public let nodeIDs: [NodeID]

    public init(id: String, size: Int64, nodeIDs: [NodeID]) {
        self.id = id
        self.size = size
        self.nodeIDs = nodeIDs
    }
}

/// A file sharing its exact size with at least one other file — the cheap,
/// in-memory first filter before any disk I/O.
struct DuplicateCandidate: Sendable {
    let id: NodeID
    let path: String
    let size: Int64
}
