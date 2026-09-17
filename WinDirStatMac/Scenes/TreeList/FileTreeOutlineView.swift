// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DirStatCore

@MainActor
private let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
}()

struct FileTreeOutlineView: NSViewRepresentable {
    var viewModel: ScanViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.headerView = NSTableHeaderView()
        outlineView.rowSizeStyle = .default
        outlineView.style = .inset

        let nameColumn = NSTableColumn(identifier: .init("name"))
        nameColumn.title = "Name"
        nameColumn.minWidth = 180
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let sizeColumn = NSTableColumn(identifier: .init("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 180
        sizeColumn.minWidth = 140
        outlineView.addTableColumn(sizeColumn)

        context.coordinator.outlineView = outlineView
        outlineView.menu = context.coordinator.makeContextMenu()

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let outlineView = scrollView.documentView as? NSOutlineView else { return }

        if coordinator.currentRootID != viewModel.zoomRootID || coordinator.lastKnownTreeVersion != viewModel.treeVersion {
            coordinator.lastKnownTreeVersion = viewModel.treeVersion
            coordinator.reset(newRoot: viewModel.zoomRootID)
            outlineView.reloadData()
        }

        if coordinator.lastAppliedSelection != viewModel.selectedNodeID {
            coordinator.applyingProgrammaticSelection = true
            defer { coordinator.applyingProgrammaticSelection = false }
            if let selected = viewModel.selectedNodeID, coordinator.revealAndSelect(selected, in: outlineView) {
                coordinator.lastAppliedSelection = selected
            } else if viewModel.selectedNodeID == nil {
                outlineView.deselectAll(nil)
                coordinator.lastAppliedSelection = nil
            }
        }
    }

    func makeCoordinator() -> FileTreeCoordinator {
        FileTreeCoordinator(viewModel: viewModel)
    }
}

@MainActor
final class FileTreeCoordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    let viewModel: ScanViewModel
    weak var outlineView: NSOutlineView?

    private(set) var currentRootID: NodeID?
    var lastAppliedSelection: NodeID?
    var applyingProgrammaticSelection = false
    var lastKnownTreeVersion = 0

    private var childrenCache: [NodeID: [NodeID]] = [:]
    private var nodeCache: [NodeID: FileSystemNode] = [:]
    private var pendingFetches: Set<NodeID> = []

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
        self.currentRootID = viewModel.zoomRootID
    }

    func reset(newRoot: NodeID?) {
        currentRootID = newRoot
        childrenCache.removeAll()
        nodeCache.removeAll()
        pendingFetches.removeAll()
        if let newRoot {
            Task { await self.hydrateNode(newRoot) }
        }
    }

    @discardableResult
    func revealAndSelect(_ id: NodeID, in outlineView: NSOutlineView) -> Bool {
        guard nodeCache[id] != nil else { return false }
        let row = outlineView.row(forItem: NSNumber(value: id.rawValue))
        guard row >= 0 else { return false }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        return true
    }

    private func hydrateNode(_ id: NodeID) async {
        if let node = await viewModel.node(id) {
            nodeCache[id] = node
        }
    }

    private func nodeID(from item: Any?) -> NodeID? {
        guard let number = item as? NSNumber else { return nil }
        return NodeID(rawValue: number.int32Value)
    }

    private func cachedChildren(of id: NodeID) -> [NodeID] {
        if let cached = childrenCache[id] { return cached }
        fetchChildren(of: id)
        return []
    }

    private func fetchChildren(of id: NodeID) {
        guard !pendingFetches.contains(id) else { return }
        pendingFetches.insert(id)
        Task {
            let kids = await viewModel.children(of: id)
            for kid in kids {
                if let node = await viewModel.node(kid) {
                    nodeCache[kid] = node
                }
            }
            childrenCache[id] = kids
            pendingFetches.remove(id)
            reloadItem(id)
        }
    }

    private func reloadItem(_ id: NodeID) {
        guard let outlineView else { return }
        if id == currentRootID {
            outlineView.reloadData()
        } else {
            outlineView.reloadItem(NSNumber(value: id.rawValue), reloadChildren: true)
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let id = nodeID(from: item) ?? currentRootID
        guard let id else { return 0 }
        return cachedChildren(of: id).count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let id = nodeID(from: item), let node = nodeCache[id] else { return false }
        return node.isDirectory && !node.isPackage && !node.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let id = nodeID(from: item) ?? currentRootID
        let kids = id.map(cachedChildren) ?? []
        guard index < kids.count else { return NSNumber(value: -1) }
        return NSNumber(value: kids[index].rawValue)
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let id = nodeID(from: item), let node = nodeCache[id] else { return nil }
        guard let identifier = tableColumn?.identifier else { return nil }

        switch identifier.rawValue {
        case "name":
            let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NameCellView ?? NameCellView()
            cell.identifier = identifier
            cell.nameLabel.stringValue = node.name
            cell.iconView.image = icon(for: node)
            return cell
        case "size":
            let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? SizeCellView ?? SizeCellView()
            cell.identifier = identifier
            let size = viewModel.sizeMode == .logical ? node.aggregateLogical : node.aggregateAllocated
            cell.sizeLabel.stringValue = byteFormatter.string(fromByteCount: size)
            cell.barView.fraction = fractionOfParent(id: id, node: node)
            return cell
        default:
            return nil
        }
    }

    private func fractionOfParent(id: NodeID, node: FileSystemNode) -> Double {
        guard let parentID = node.parent, let parent = nodeCache[parentID] else { return 1 }
        let parentSize = viewModel.sizeMode == .logical ? parent.aggregateLogical : parent.aggregateAllocated
        guard parentSize > 0 else { return 0 }
        let ownSize = viewModel.sizeMode == .logical ? node.aggregateLogical : node.aggregateAllocated
        return Double(ownSize) / Double(parentSize)
    }

    private func icon(for node: FileSystemNode) -> NSImage? {
        if node.isMountPoint {
            return NSWorkspace.shared.icon(for: .volume)
        }
        if node.isPackage {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        if node.isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }
        if let dotIndex = node.name.lastIndex(of: "."), dotIndex != node.name.startIndex {
            let ext = String(node.name[node.name.index(after: dotIndex)...])
            if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
                return NSWorkspace.shared.icon(for: type)
            }
        }
        return NSWorkspace.shared.icon(for: .item)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !applyingProgrammaticSelection, let outlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row), let id = nodeID(from: item) else {
            if viewModel.selectedNodeID != nil {
                viewModel.selectedNodeID = nil
                lastAppliedSelection = nil
            }
            return
        }
        viewModel.selectedNodeID = id
        lastAppliedSelection = id
    }

    // MARK: Context menu / cleanup actions

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Revelar en Finder", action: #selector(revealClicked), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Abrir", action: #selector(openClicked), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Mover a la Papelera", action: #selector(trashClicked), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Eliminar…", action: #selector(deleteClicked), keyEquivalent: "").target = self
        return menu
    }

    private func clickedNodeID() -> NodeID? {
        guard let outlineView, outlineView.clickedRow >= 0, let item = outlineView.item(atRow: outlineView.clickedRow) else { return nil }
        return nodeID(from: item)
    }

    @objc private func revealClicked() {
        guard let id = clickedNodeID() else { return }
        Task { await viewModel.revealInFinder(id) }
    }

    @objc private func openClicked() {
        guard let id = clickedNodeID() else { return }
        Task { await viewModel.openWithDefaultApplication(id) }
    }

    @objc private func trashClicked() {
        guard let id = clickedNodeID() else { return }
        confirmIfNeeded(message: "¿Mover este elemento a la Papelera?", detail: "Podrás recuperarlo desde la Papelera.", alwaysConfirm: false) {
            Task { await self.viewModel.moveToTrash(id) }
        }
    }

    @objc private func deleteClicked() {
        guard let id = clickedNodeID() else { return }
        confirmIfNeeded(message: "¿Eliminar este elemento permanentemente?", detail: "Esta acción no se puede deshacer.", alwaysConfirm: true) {
            Task { await self.viewModel.deletePermanently(id) }
        }
    }

    private func confirmIfNeeded(message: String, detail: String, alwaysConfirm: Bool, perform: @escaping () -> Void) {
        guard alwaysConfirm || AppSettings.shared.confirmBeforeDelete else {
            perform()
            return
        }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "Continuar")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn {
            perform()
        }
    }
}
