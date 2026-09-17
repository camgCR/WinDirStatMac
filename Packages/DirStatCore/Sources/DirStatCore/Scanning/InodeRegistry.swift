// SPDX-License-Identifier: GPL-2.0-or-later
import Darwin

/// Identifies a file's actual data, independent of which directory entry (name)
/// points at it. Two different paths with the same `(device, inode)` are hard
/// links to the exact same bytes on disk.
private struct InodeKey: Hashable, Sendable {
    let device: dev_t
    let inode: ino_t
}

/// Tracks which hard-linked files have already been counted during a scan.
///
/// macOS system volumes (and Xcode/CoreSimulator installs especially) make heavy
/// use of hard links — the same on-disk bytes reachable from multiple paths. Only
/// checking `st_nlink > 1` files against this (the common case, `st_nlink == 1`,
/// skips the registry entirely) keeps the overhead limited to files that actually
/// need it, while still letting every hard-linked file count exactly once instead
/// of once per link — otherwise a scan can report more bytes than the volume
/// physically holds.
actor InodeRegistry {
    private var seen: Set<InodeKey> = []

    /// Batched so a directory with several hard-linked files costs one actor hop,
    /// not one per file. Returns, in the same order as `keys`, `true` for the
    /// first claim of each `(device, inode)` seen across the whole scan and
    /// `false` for every later one — callers should count the size only on `true`.
    func claimFirstOccurrences(_ keys: [(device: dev_t, inode: ino_t)]) -> [Bool] {
        keys.map { seen.insert(InodeKey(device: $0.device, inode: $0.inode)).inserted }
    }
}
