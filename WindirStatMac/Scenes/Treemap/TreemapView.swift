import SwiftUI
import DirStatCore

struct TreemapView: NSViewRepresentable {
    var viewModel: ScanViewModel

    func makeNSView(context: Context) -> TreemapNSView {
        let view = TreemapNSView()
        context.coordinator.treemapView = view
        view.onSelect = { [coordinator = context.coordinator] id in coordinator.handleSelect(id) }
        view.onHover = { [coordinator = context.coordinator] id in coordinator.handleHover(id) }
        view.onZoomRequest = { [coordinator = context.coordinator] id in coordinator.handleZoomRequest(id) }
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

/// Minimum on-screen tile area (points²) before recursion into a directory's
/// children stops and it's drawn as a single flat tile instead.
private let minTileArea = 12.0

@MainActor
final class TreemapCoordinator: NSObject {
    let viewModel: ScanViewModel
    weak var treemapView: TreemapNSView?

    private var lastZoomRoot: NodeID?
    private var lastSizeMode: SizeMode?
    private var lastSize: CGSize = .zero
    private var recomputeTask: Task<Void, Never>?

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
    }

    func recomputeIfNeeded(bounds: CGSize) {
        guard let zoomRoot = viewModel.zoomRootID, bounds.width > 0, bounds.height > 0 else { return }
        let needsRecompute = lastZoomRoot != zoomRoot || lastSizeMode != viewModel.sizeMode || lastSize != bounds
        guard needsRecompute else { return }

        lastZoomRoot = zoomRoot
        lastSizeMode = viewModel.sizeMode
        lastSize = bounds

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
}
