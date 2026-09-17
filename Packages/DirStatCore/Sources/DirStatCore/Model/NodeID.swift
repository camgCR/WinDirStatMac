// SPDX-License-Identifier: GPL-2.0-or-later
/// Identifies a node inside a `FileSystemTree`'s arena. Stable across mutation,
/// so it can be handed to AppKit (e.g. as an NSOutlineView item) as an opaque token.
public struct NodeID: Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}
