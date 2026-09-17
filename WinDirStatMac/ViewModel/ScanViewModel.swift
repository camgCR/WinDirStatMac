// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import Observation
import DirStatCore

enum ScanState: Equatable {
    case idle
    case scanning(ScanProgress)
    case completed
}

/// Single source of truth for the app's UI. Both the tree list and (from Phase C
/// on) the treemap read and write `selectedNodeID`/`hoveredNodeID` here so the two
/// views stay in sync without talking to each other directly.
@MainActor
@Observable
final class ScanViewModel {
    private(set) var scanState: ScanState = .idle
    private(set) var tree: FileSystemTree?
    private(set) var rootID: NodeID?
    private(set) var scannedPath: String?
    private(set) var deniedPathCount: Int = 0
    var lastErrorMessage: String?
    /// Bumped whenever the tree's shape changes outside of a normal scan (i.e. a
    /// cleanup action), so the tree list and treemap know to invalidate their
    /// local caches and re-fetch even though `rootID`/`zoomRootID` didn't change.
    private(set) var treeVersion: Int = 0

    var zoomRootID: NodeID?
    var selectedNodeID: NodeID?
    var hoveredNodeID: NodeID?
    var sizeMode: SizeMode {
        didSet { AppSettings.shared.sizeMode = sizeMode }
    }
    var treatPackagesAsFiles: Bool {
        didSet { AppSettings.shared.treatPackagesAsFiles = treatPackagesAsFiles }
    }

    private var scanTask: Task<Void, Never>?

    init() {
        sizeMode = AppSettings.shared.sizeMode
        treatPackagesAsFiles = AppSettings.shared.treatPackagesAsFiles
    }

    func startScan(path: String) {
        scanTask?.cancel()
        selectedNodeID = nil
        hoveredNodeID = nil
        scannedPath = path
        scanState = .scanning(ScanProgress())

        let options = ScanOptions(treatPackagesAsFiles: treatPackagesAsFiles)
        let scanner = DirectoryScanner(options: options)
        let progressCounter = ScanProgressCounter()

        scanTask = Task { [weak self] in
            guard let self else { return }
            async let scanned = scanner.scan(rootPath: path, progress: progressCounter)
            await self.pollProgress(progressCounter)
            let resultTree = await scanned
            guard !Task.isCancelled else { return }
            self.tree = resultTree
            self.rootID = await resultTree.rootID
            self.zoomRootID = self.rootID
            self.deniedPathCount = await resultTree.deniedPaths.count
            self.scanState = .completed
        }
    }

    /// Re-runs the scan against the same path (e.g. after the user grants Full
    /// Disk Access in System Settings).
    func rescan() {
        guard let scannedPath else { return }
        startScan(path: scannedPath)
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func pollProgress(_ counter: ScanProgressCounter) async {
        while !Task.isCancelled {
            let snapshot = await counter.snapshot()
            scanState = .scanning(snapshot)
            if snapshot.isComplete { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func children(of id: NodeID) async -> [NodeID] {
        guard let tree else { return [] }
        return await tree.children(of: id, sortedBy: sizeMode)
    }

    func node(_ id: NodeID) async -> FileSystemNode? {
        await tree?.node(id)
    }

    func extensionStats() async -> [ExtensionStats] {
        guard let tree else { return [] }
        return await tree.extensionStats()
    }

    func extensionName(for id: ExtensionID) async -> String? {
        await tree?.extensionName(for: id)
    }

    func extensionNames(for ids: [ExtensionID]) async -> [ExtensionID: String] {
        guard let tree else { return [:] }
        return await tree.extensionNames(for: ids)
    }

    func setZoomRoot(_ id: NodeID) {
        zoomRootID = id
        selectedNodeID = nil
    }

    /// Renders the whole current scan as CSV text, or `nil` if nothing's been
    /// scanned yet.
    func exportCSV() async -> String? {
        guard let tree else { return nil }
        let rows = await tree.exportRows()
        return CSVFormatter.format(rows: rows)
    }

    /// `onProgress` is polled at ~10Hz (not pushed per-file) while the scan
    /// runs, same pattern as the initial directory scan's progress bar.
    func findDuplicates(onProgress: @escaping (DuplicateScanProgress.Snapshot) -> Void) async -> [DuplicateGroup] {
        guard let tree else { return [] }
        let progress = DuplicateScanProgress()
        let pollTask = Task {
            while !Task.isCancelled {
                onProgress(await progress.snapshot())
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { pollTask.cancel() }
        return await DuplicateFinder.findDuplicates(in: tree, progress: progress)
    }

    func search(query: String) async -> [SearchResult] {
        guard let tree else { return [] }
        return await tree.search(query: query, sizeMode: sizeMode)
    }

    /// Zooms to the result's containing folder and selects it there — the
    /// result becomes a top-level, already-visible item under the new zoom
    /// root in both the tree list and the treemap, without needing to expand
    /// every ancestor along the way first.
    func revealSearchResult(_ result: SearchResult) async {
        guard let node = await node(result.id), let parentID = node.parent else { return }
        setZoomRoot(parentID)
        selectedNodeID = result.id
    }

    /// The chain of directory names from the scan root down to the current zoom
    /// root, for a breadcrumb control (`[(id, name)]`, root first).
    func breadcrumbPath() async -> [(id: NodeID, name: String)] {
        guard let zoomRootID else { return [] }
        var chain: [(id: NodeID, name: String)] = []
        var current: NodeID? = zoomRootID
        while let id = current {
            guard let node = await self.node(id) else { break }
            chain.append((id, node.name))
            current = node.parent
        }
        return chain.reversed()
    }

    func fullPath(of id: NodeID) async -> String? {
        await tree?.fullPath(of: id)
    }

    func revealInFinder(_ id: NodeID) async {
        guard let path = await fullPath(of: id) else { return }
        CleanupActions.revealInFinder(path: path)
    }

    func openWithDefaultApplication(_ id: NodeID) async {
        guard let path = await fullPath(of: id) else { return }
        CleanupActions.openWithDefaultApplication(path: path)
    }

    func moveToTrash(_ id: NodeID) async {
        guard let path = await fullPath(of: id) else { return }
        do {
            try CleanupActions.moveToTrash(path: path)
            await detachFromTree(id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deletePermanently(_ id: NodeID) async {
        guard let path = await fullPath(of: id) else { return }
        do {
            try CleanupActions.deletePermanently(path: path)
            await detachFromTree(id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Removes `id` from the in-memory tree and rolls the size change up its
    /// ancestors, without a full rescan — called after the file was actually
    /// deleted on disk.
    private func detachFromTree(_ id: NodeID) async {
        guard let tree else { return }
        guard let parentID = await tree.removeFromTree(id) else { return }
        if selectedNodeID == id { selectedNodeID = parentID }
        if hoveredNodeID == id { hoveredNodeID = nil }
        if zoomRootID == id { zoomRootID = parentID }
        treeVersion += 1
    }
}
