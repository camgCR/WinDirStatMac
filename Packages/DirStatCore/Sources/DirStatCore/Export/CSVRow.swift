// SPDX-License-Identifier: GPL-2.0-or-later
public enum CSVEntryType: String, Sendable {
    case file = "file"
    case directory = "directory"
    case package = "package"
    case symlink = "symlink"
    case mountPoint = "mount-point"
    case permissionDenied = "permission-denied"
}

/// One row of a scan's CSV export. `path` is relative to the scanned root and
/// includes the item's own name (e.g. "sub/dir/file.txt"), not an absolute
/// filesystem path — the scan root itself may not be `/`, and a relative path is
/// what stays meaningful if the CSV is opened on a different machine.
public struct CSVRow: Sendable, Equatable {
    public let path: String
    public let name: String
    public let type: CSVEntryType
    public let sizeLogical: Int64
    public let sizeAllocated: Int64
    public let extensionName: String?

    public init(path: String, name: String, type: CSVEntryType, sizeLogical: Int64, sizeAllocated: Int64, extensionName: String?) {
        self.path = path
        self.name = name
        self.type = type
        self.sizeLogical = sizeLogical
        self.sizeAllocated = sizeAllocated
        self.extensionName = extensionName
    }
}
