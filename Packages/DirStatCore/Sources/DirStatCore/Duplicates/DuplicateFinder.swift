// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// Finds byte-identical files across a scanned tree: group by exact size
/// (cheap, in-memory, done inside `FileSystemTree`), then narrow with a cheap
/// partial-content hash, then confirm survivors with a full-content hash — so
/// the expensive full read only happens for files that already matched on
/// both size and the first few KB. All the disk I/O here runs outside the
/// `FileSystemTree` actor (via a bounded `TaskGroup`), so scanning for
/// duplicates never blocks the tree list or treemap from reading the tree.
public enum DuplicateFinder {
    public static func findDuplicates(
        in tree: FileSystemTree,
        maxConcurrency: Int = ProcessInfo.processInfo.activeProcessorCount,
        progress: DuplicateScanProgress? = nil
    ) async -> [DuplicateGroup] {
        let candidates = await tree.duplicateCandidates()
        guard !candidates.isEmpty else { return [] }

        await progress?.startPhase(1, total: candidates.count)
        let partialGroups = await hashAndGroup(candidates, limit: maxConcurrency, progress: progress) {
            FileHasher.partialHash(path: $0.path)
        }
        guard !Task.isCancelled else { return [] }

        let survivors = partialGroups.values.filter { $0.count >= 2 }.flatMap { $0 }
        guard !survivors.isEmpty else { return [] }

        await progress?.startPhase(2, total: survivors.count)
        let fullGroups = await hashAndGroup(survivors, limit: maxConcurrency, progress: progress) {
            FileHasher.fullHash(path: $0.path)
        }
        guard !Task.isCancelled else { return [] }

        return fullGroups.values
            .filter { $0.count >= 2 }
            .map { group in
                DuplicateGroup(id: group[0].size.description + ":" + group.map(\.id.rawValue.description).sorted().joined(separator: ","), size: group[0].size, nodeIDs: group.map(\.id))
            }
            .sorted { $0.size * Int64($0.nodeIDs.count) > $1.size * Int64($1.nodeIDs.count) }
    }

    /// Hashes every candidate (bounded concurrency — `limit` files being read
    /// at once) and groups the results by `"<size>-<hash>"`. Candidates whose
    /// hash couldn't be computed (vanished, permission issue) are dropped.
    /// Stops launching new work as soon as the calling task is cancelled —
    /// e.g. the user dismissed the "Duplicate Files" sheet — rather than
    /// grinding through every remaining candidate regardless.
    private static func hashAndGroup(
        _ candidates: [DuplicateCandidate],
        limit: Int,
        progress: DuplicateScanProgress?,
        hash: @escaping @Sendable (DuplicateCandidate) -> String?
    ) async -> [String: [DuplicateCandidate]] {
        var groups: [String: [DuplicateCandidate]] = [:]
        await withTaskGroup(of: (DuplicateCandidate, String?).self) { group in
            var iterator = candidates.makeIterator()

            func addNext() {
                guard !Task.isCancelled, let candidate = iterator.next() else { return }
                group.addTask { (candidate, hash(candidate)) }
            }

            for _ in 0..<max(1, limit) { addNext() }
            while let (candidate, hashValue) = await group.next() {
                if let hashValue {
                    groups["\(candidate.size)-\(hashValue)", default: []].append(candidate)
                }
                await progress?.increment()
                addNext()
            }
        }
        return groups
    }
}
