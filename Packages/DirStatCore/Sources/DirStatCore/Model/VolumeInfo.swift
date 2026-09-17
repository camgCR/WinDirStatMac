// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// A mountable/scannable root, e.g. a volume or an arbitrary user-chosen folder.
public struct VolumeInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let url: URL
    public let displayName: String
    public let totalCapacity: Int64?
    public let availableCapacity: Int64?

    public init(url: URL, displayName: String, totalCapacity: Int64?, availableCapacity: Int64?) {
        self.id = url.path
        self.url = url
        self.displayName = displayName
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
    }
}
