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
            self.scanState = .completed
        }
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

    func setZoomRoot(_ id: NodeID) {
        zoomRootID = id
        selectedNodeID = nil
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
}
