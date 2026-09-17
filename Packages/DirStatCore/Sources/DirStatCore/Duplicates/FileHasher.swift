// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import CryptoKit

/// Content hashing for duplicate detection. Two tiers on purpose: a
/// `partialHash` over just the first few KB is enough to discard the large
/// majority of same-size-but-different-content files cheaply; only candidates
/// that still match after that pay for a `fullHash` over the entire file,
/// streamed in chunks so large files don't need to be loaded into memory whole.
enum FileHasher {
    static func partialHash(path: String, byteLimit: Int = 4096) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: byteLimit) else { return nil }
        return hexString(SHA256.hash(data: data))
    }

    static func fullHash(path: String, chunkSize: Int = 1 << 20) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hexString(hasher.finalize())
    }

    private static func hexString(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
