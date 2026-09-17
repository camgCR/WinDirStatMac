// SPDX-License-Identifier: GPL-2.0-or-later
import Darwin

/// Caps how many directory-scan tasks may run concurrently, so a wide directory
/// doesn't spawn unbounded tasks and a deep one doesn't starve the cooperative
/// thread pool. Checked before recursing into each subdirectory: if budget remains,
/// the subdirectory is scanned in its own child task; otherwise it's scanned inline.
actor ConcurrencyBudget {
    private var remaining: Int

    init(limit: Int) {
        remaining = max(1, limit)
    }

    func tryAcquire() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }

    func release() {
        remaining += 1
    }
}

/// Extracts a file's extension the way the extension list means it: the suffix
/// after the last '.', excluding a leading dot that makes the whole name a dotfile
/// (".gitignore" has no extension; "archive.tar.gz" has extension "gz").
func fileExtension(of name: String) -> String? {
    guard let dotIndex = name.lastIndex(of: "."), dotIndex != name.startIndex else { return nil }
    let ext = name[name.index(after: dotIndex)...]
    return ext.isEmpty ? nil : String(ext)
}

public struct DirectoryScanner: Sendable {
    public let options: ScanOptions

    public init(options: ScanOptions = ScanOptions()) {
        self.options = options
    }

    /// Scans `rootPath` into a fresh `FileSystemTree`. `progress` (if provided) is
    /// updated throughout the scan and should be sampled periodically (e.g. every
    /// 100ms) by the caller rather than awaited for completion.
    public func scan(rootPath: String, progress: ScanProgressCounter? = nil) async -> FileSystemTree {
        let tree = FileSystemTree()
        let rootName = displayName(forPath: rootPath)
        let rootID = await tree.makeRoot(name: rootName)

        guard let rootFD = POSIXFileEnumerator.openDirectory(atPath: rootPath) else {
            await tree.recordDeniedPaths([rootPath])
            await progress?.markComplete()
            return tree
        }

        var rootStat = stat()
        let rootDevice: dev_t = fstat(rootFD, &rootStat) == 0 ? rootStat.st_dev : 0

        let budget = ConcurrencyBudget(limit: options.maxConcurrency)
        let inodeRegistry = InodeRegistry()
        let result = await scanDirectoryContents(fd: rootFD, path: rootPath, rootDevice: rootDevice, inodeRegistry: inodeRegistry, budget: budget, progress: progress)
        await tree.mergeChildren(into: rootID, result: result)
        await tree.recordDeniedPaths(result.deniedPaths)
        await tree.finalizeAggregation()
        await progress?.markComplete()
        return tree
    }

    private func displayName(forPath path: String) -> String {
        let trimmed = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
        guard let lastSlash = trimmed.lastIndex(of: "/"), trimmed.index(after: lastSlash) != trimmed.endIndex else {
            return trimmed
        }
        return String(trimmed[trimmed.index(after: lastSlash)...])
    }

    /// Scans the contents of an already-open directory fd (takes ownership of it).
    /// Recurses into subdirectories, fanning out into child tasks while `budget`
    /// allows and falling back to inline recursion once it's exhausted.
    private func scanDirectoryContents(fd: Int32, path: String, rootDevice: dev_t, inodeRegistry: InodeRegistry, budget: ConcurrencyBudget, progress: ScanProgressCounter?) async -> LocalScanResult {
        guard !Task.isCancelled else {
            close(fd)
            return LocalScanResult()
        }
        let entries = POSIXFileEnumerator.listEntries(parentFD: fd)
        var result = LocalScanResult()

        var directLeafCount = 0
        var directLeafBytes: Int64 = 0

        // Hard-linked files (st_nlink > 1 — common on macOS system volumes and
        // especially Xcode/CoreSimulator installs) point at the same on-disk
        // bytes from multiple paths; counting each link's full size would report
        // more bytes than the volume actually holds. Resolved as one batched
        // actor call per directory rather than one per linked file.
        let leafEntries = entries.filter { !$0.isDirectory }
        let linkedIndices = leafEntries.indices.filter { leafEntries[$0].stat.st_nlink > 1 }
        var isFirstOccurrence: [Int: Bool] = [:]
        if !linkedIndices.isEmpty {
            let keys = linkedIndices.map { (device: leafEntries[$0].stat.st_dev, inode: leafEntries[$0].stat.st_ino) }
            let results = await inodeRegistry.claimFirstOccurrences(keys)
            for (offset, index) in linkedIndices.enumerated() {
                isFirstOccurrence[index] = results[offset]
            }
        }

        for (index, entry) in leafEntries.enumerated() {
            let ext = entry.isSymlink ? nil : fileExtension(of: entry.name)
            let extensionID = ext.map { result.extensionTable.intern($0) } ?? .none
            let alreadyCounted = isFirstOccurrence[index] == false
            let sizeLogical = alreadyCounted ? 0 : Int64(entry.stat.st_size)
            let sizeAllocated = alreadyCounted ? 0 : Int64(entry.stat.st_blocks) * 512
            result.addLeaf(name: entry.name, extensionID: extensionID, sizeLogical: sizeLogical, sizeAllocated: sizeAllocated, isSymlink: entry.isSymlink)
            directLeafCount += 1
            directLeafBytes += sizeLogical
        }

        var inlineDirs: [RawDirEntry] = []
        var spawnedDirs: [RawDirEntry] = []
        for entry in entries where entry.isDirectory {
            // Never cross into a different filesystem than the scan root: sibling
            // APFS volumes in the same container share underlying free space, so
            // recursing into every mount nested under the root (other volumes,
            // disk images, network shares...) would double-count real disk usage
            // rather than just reporting more of it. The mount point itself is
            // still recorded, with its own shallow size, just not traversed.
            guard entry.stat.st_dev == rootDevice else {
                if let childFD = entry.childFD { close(childFD) }
                result.addMountPoint(
                    name: entry.name,
                    sizeLogical: Int64(entry.stat.st_size),
                    sizeAllocated: Int64(entry.stat.st_blocks) * 512
                )
                continue
            }
            guard entry.childFD != nil else {
                result.addPermissionDeniedDirectory(name: entry.name, path: "\(path)/\(entry.name)")
                continue
            }
            if await budget.tryAcquire() {
                spawnedDirs.append(entry)
            } else {
                inlineDirs.append(entry)
            }
        }

        await withTaskGroup(of: (String, Bool, LocalScanResult).self) { group in
            for entry in spawnedDirs {
                let name = entry.name
                let childFD = entry.childFD!
                let asPackage = options.treatPackagesAsFiles && isPackageName(name)
                let childPath = "\(path)/\(name)"
                group.addTask {
                    let childResult = await self.scanDirectoryContents(fd: childFD, path: childPath, rootDevice: rootDevice, inodeRegistry: inodeRegistry, budget: budget, progress: progress)
                    await budget.release()
                    return (name, asPackage, childResult)
                }
            }
            for await (name, asPackage, childResult) in group {
                result.addDirectory(name: name, childResult: childResult, asPackage: asPackage)
            }
        }

        for entry in inlineDirs {
            let asPackage = options.treatPackagesAsFiles && isPackageName(entry.name)
            let childResult = await scanDirectoryContents(fd: entry.childFD!, path: "\(path)/\(entry.name)", rootDevice: rootDevice, inodeRegistry: inodeRegistry, budget: budget, progress: progress)
            result.addDirectory(name: entry.name, childResult: childResult, asPackage: asPackage)
        }

        await progress?.record(files: directLeafCount, bytes: directLeafBytes)
        return result
    }

    private func isPackageName(_ name: String) -> Bool {
        guard let ext = fileExtension(of: name) else { return false }
        return BundleDetection.isKnownPackageExtension(ext)
    }
}
