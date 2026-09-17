// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

/// Assigns a stable color to each file extension, shared by the treemap and (from
/// Phase D) the extension list, so the same extension always reads as the same
/// color across both views and across app launches. Hashing the extension's NAME
/// (not its `ExtensionID`, which is only stable within a single scan session) is
/// what makes colors consistent run to run.
enum ExtensionColorPalette {
    private static let swatches: [NSColor] = [
        NSColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1), // blue
        NSColor(red: 0.93, green: 0.53, blue: 0.20, alpha: 1), // orange
        NSColor(red: 0.36, green: 0.72, blue: 0.40, alpha: 1), // green
        NSColor(red: 0.85, green: 0.33, blue: 0.38, alpha: 1), // red
        NSColor(red: 0.58, green: 0.44, blue: 0.86, alpha: 1), // purple
        NSColor(red: 0.85, green: 0.75, blue: 0.24, alpha: 1), // yellow
        NSColor(red: 0.29, green: 0.76, blue: 0.75, alpha: 1), // teal
        NSColor(red: 0.87, green: 0.47, blue: 0.65, alpha: 1), // pink
        NSColor(red: 0.53, green: 0.62, blue: 0.33, alpha: 1), // olive
        NSColor(red: 0.42, green: 0.47, blue: 0.82, alpha: 1), // indigo
        NSColor(red: 0.80, green: 0.60, blue: 0.42, alpha: 1), // tan
        NSColor(red: 0.40, green: 0.72, blue: 0.86, alpha: 1), // sky
    ]

    static let directoryColor = NSColor(white: 0.55, alpha: 1)
    static let packageColor = NSColor(red: 0.42, green: 0.47, blue: 0.82, alpha: 1)
    static let noExtensionColor = NSColor(white: 0.65, alpha: 1)
    /// Dark reddish-brown, distinct from every other tile color, for locations the
    /// scan couldn't read (almost always missing Full Disk Access) — so it reads
    /// as "unknown / blocked" rather than looking like an ordinary empty folder.
    static let permissionDeniedColor = NSColor(red: 0.45, green: 0.24, blue: 0.22, alpha: 1)
    /// Dark teal for mount points (other volumes, disk images, network shares)
    /// that the scan deliberately doesn't descend into — see
    /// `FileSystemNode.isMountPoint`.
    static let mountPointColor = NSColor(red: 0.16, green: 0.35, blue: 0.38, alpha: 1)

    static func color(forExtension name: String?) -> NSColor {
        guard let name, !name.isEmpty else { return noExtensionColor }
        return swatches[stableHash(name) % swatches.count]
    }

    /// A fixed (non-randomized) string hash — `Hashable`/`Hasher` is seeded
    /// per-process for DoS resistance, so it would assign a different color to
    /// the same extension on every launch. FNV-1a here is simple and stable.
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(Int.max))
    }
}
