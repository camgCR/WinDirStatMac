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

        let budget = ConcurrencyBudget(limit: options.maxConcurrency)
        let result = await scanDirectoryContents(fd: rootFD, path: rootPath, budget: budget, progress: progress)
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
    private func scanDirectoryContents(fd: Int32, path: String, budget: ConcurrencyBudget, progress: ScanProgressCounter?) async -> LocalScanResult {
        guard !Task.isCancelled else {
            close(fd)
            return LocalScanResult()
        }
        let entries = POSIXFileEnumerator.listEntries(parentFD: fd)
        var result = LocalScanResult()

        var directLeafCount = 0
        var directLeafBytes: Int64 = 0

        for entry in entries where !entry.isDirectory {
            let ext = entry.isSymlink ? nil : fileExtension(of: entry.name)
            let extensionID = ext.map { result.extensionTable.intern($0) } ?? .none
            let sizeLogical = Int64(entry.stat.st_size)
            let sizeAllocated = Int64(entry.stat.st_blocks) * 512
            result.addLeaf(name: entry.name, extensionID: extensionID, sizeLogical: sizeLogical, sizeAllocated: sizeAllocated, isSymlink: entry.isSymlink)
            directLeafCount += 1
            directLeafBytes += sizeLogical
        }

        var inlineDirs: [RawDirEntry] = []
        var spawnedDirs: [RawDirEntry] = []
        for entry in entries where entry.isDirectory {
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
                    let childResult = await self.scanDirectoryContents(fd: childFD, path: childPath, budget: budget, progress: progress)
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
            let childResult = await scanDirectoryContents(fd: entry.childFD!, path: "\(path)/\(entry.name)", budget: budget, progress: progress)
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
