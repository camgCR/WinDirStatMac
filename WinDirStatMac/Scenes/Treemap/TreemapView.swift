// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import DirStatCore

struct TreemapView: NSViewRepresentable {
    var viewModel: ScanViewModel

    func makeNSView(context: Context) -> TreemapNSView {
        let view = TreemapNSView()
        context.coordinator.treemapView = view
        view.onSelect = { [coordinator = context.coordinator] id in coordinator.handleSelect(id) }
        view.onHover = { [coordinator = context.coordinator] id in coordinator.handleHover(id) }
        view.onZoomRequest = { [coordinator = context.coordinator] id in coordinator.handleZoomRequest(id) }
        view.onReveal = { [coordinator = context.coordinator] id in coordinator.handleReveal(id) }
        view.onOpen = { [coordinator = context.coordinator] id in coordinator.handleOpen(id) }
        view.onTrash = { [coordinator = context.coordinator] id in coordinator.handleTrash(id) }
        view.onDelete = { [coordinator = context.coordinator] id in coordinator.handleDelete(id) }
        return view
    }

    func updateNSView(_ nsView: TreemapNSView, context: Context) {
        nsView.selectedID = viewModel.selectedNodeID
        nsView.hoveredID = viewModel.hoveredNodeID
        context.coordinator.recomputeIfNeeded(bounds: nsView.bounds.size)
    }

    func makeCoordinator() -> TreemapCoordinator {
        TreemapCoordinator(viewModel: viewModel)
    }
}

@MainActor
final class TreemapCoordinator: NSObject {
    let viewModel: ScanViewModel
    weak var treemapView: TreemapNSView?

    private var lastZoomRoot: NodeID?
    private var lastSizeMode: SizeMode?
    private var lastSize: CGSize = .zero
    private var lastMinTileArea: Double?
    private var lastTreeVersion: Int?
    private var recomputeTask: Task<Void, Never>?

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
    }

    func recomputeIfNeeded(bounds: CGSize) {
        guard let zoomRoot = viewModel.zoomRootID, bounds.width > 0, bounds.height > 0 else { return }
        let minTileArea = AppSettings.shared.treemapMinTileArea
        let needsRecompute = lastZoomRoot != zoomRoot || lastSizeMode != viewModel.sizeMode || lastSize != bounds
            || lastMinTileArea != minTileArea || lastTreeVersion != viewModel.treeVersion
        guard needsRecompute else { return }

        lastZoomRoot = zoomRoot
        lastSizeMode = viewModel.sizeMode
        lastSize = bounds
        lastMinTileArea = minTileArea
        lastTreeVersion = viewModel.treeVersion

        let treemapBounds = TreemapRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        recomputeTask?.cancel()
        recomputeTask = Task { [viewModel] in
            let tiles = await TreemapLayoutEngine.buildTiles(rootID: zoomRoot, bounds: treemapBounds, minTileArea: minTileArea, viewModel: viewModel)
            guard !Task.isCancelled else { return }
            treemapView?.tiles = tiles
        }
    }

    func handleSelect(_ id: NodeID?) {
        viewModel.selectedNodeID = id
    }

    func handleHover(_ id: NodeID?) {
        viewModel.hoveredNodeID = id
    }

    func handleZoomRequest(_ id: NodeID) {
        viewModel.setZoomRoot(id)
        lastZoomRoot = nil // force a relayout on the next pass even if the view's bounds haven't changed
    }

    func handleReveal(_ id: NodeID) {
        Task { await viewModel.revealInFinder(id) }
    }

    func handleOpen(_ id: NodeID) {
        Task { await viewModel.openWithDefaultApplication(id) }
    }

    func handleTrash(_ id: NodeID) {
        confirmIfNeeded(message: loc("Move this item to the Trash?"), detail: loc("You can restore it from the Trash."), alwaysConfirm: false) {
            Task { await self.viewModel.moveToTrash(id) }
        }
    }

    func handleDelete(_ id: NodeID) {
        confirmIfNeeded(message: loc("Permanently delete this item?"), detail: loc("This action cannot be undone."), alwaysConfirm: true) {
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
        alert.addButton(withTitle: loc("Continue"))
        alert.addButton(withTitle: loc("Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            perform()
        }
    }
}
