import AppKit
import DirStatCore

/// Renders a flat list of pre-laid-out `TreemapTile`s with Core Graphics and
/// handles hover/click/zoom interaction. Layout itself is computed elsewhere
/// (`TreemapLayoutEngine`, driven by the coordinator) and only handed to this view
/// to draw — `tiles` is treated as immutable per assignment, recomputed only on
/// resize, zoom, subtree, or sort-mode changes, never per frame.
final class TreemapNSView: NSView {
    var tiles: [TreemapTile] = [] {
        didSet { needsDisplay = true }
    }
    var selectedID: NodeID? {
        didSet { if oldValue != selectedID { needsDisplay = true } }
    }
    var hoveredID: NodeID? {
        didSet { if oldValue != hoveredID { needsDisplay = true } }
    }

    var onSelect: ((NodeID?) -> Void)?
    var onZoomRequest: ((NodeID) -> Void)?
    var onHover: ((NodeID?) -> Void)?
    var onReveal: ((NodeID) -> Void)?
    var onOpen: ((NodeID) -> Void)?
    var onTrash: ((NodeID) -> Void)?
    var onDelete: ((NodeID) -> Void)?

    private var trackingArea: NSTrackingArea?

    private static let cushionGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.35).cgColor,
            NSColor.clear.cgColor,
            NSColor.black.withAlphaComponent(0.25).cgColor,
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        for tile in tiles {
            let cgRect = CGRect(x: tile.rect.x, y: tile.rect.y, width: tile.rect.width, height: tile.rect.height)
            guard cgRect.intersects(dirtyRect) else { continue }
            draw(tile: tile, in: cgRect, context: context)
        }
    }

    private func draw(tile: TreemapTile, in rect: CGRect, context: CGContext) {
        let baseColor = fillColor(for: tile)
        let insetRect = rect.insetBy(dx: 0.5, dy: 0.5)

        context.saveGState()
        context.setFillColor(baseColor.cgColor)
        context.fill(insetRect)

        if insetRect.width > 1, insetRect.height > 1 {
            context.clip(to: insetRect)
            context.drawLinearGradient(
                Self.cushionGradient,
                start: CGPoint(x: insetRect.midX, y: insetRect.minY),
                end: CGPoint(x: insetRect.midX, y: insetRect.maxY),
                options: []
            )
        }
        context.restoreGState()

        context.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1)
        context.stroke(insetRect)

        if tile.id == selectedID {
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(2)
            context.stroke(rect.insetBy(dx: 1, dy: 1))
        } else if tile.id == hoveredID {
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(1.5)
            context.stroke(rect.insetBy(dx: 1, dy: 1))
        }

        drawLabelIfRoom(tile: tile, in: rect)
    }

    private func drawLabelIfRoom(tile: TreemapTile, in rect: CGRect) {
        guard rect.width > 40, rect.height > 16 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white,
        ]
        let text = tile.node.name as NSString
        let padding: CGFloat = 3
        let textRect = rect.insetBy(dx: padding, dy: padding)
        text.draw(
            with: CGRect(x: textRect.minX, y: textRect.minY, width: textRect.width, height: 12),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }

    private func fillColor(for tile: TreemapTile) -> NSColor {
        if tile.node.isPackage { return ExtensionColorPalette.packageColor }
        if tile.node.isDirectory { return ExtensionColorPalette.directoryColor }
        return ExtensionColorPalette.color(forExtension: tile.extensionName)
    }

    private func tile(at point: NSPoint) -> TreemapTile? {
        for tile in tiles {
            let rect = CGRect(x: tile.rect.x, y: tile.rect.y, width: tile.rect.width, height: tile.rect.height)
            if rect.contains(point) { return tile }
        }
        return nil
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = tile(at: point)
        if hit?.id != hoveredID {
            hoveredID = hit?.id
            onHover?(hit?.id)
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredID = nil
        onHover?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = tile(at: point) else {
            onSelect?(nil)
            return
        }
        onSelect?(hit.id)

        if event.clickCount >= 2 {
            if hit.node.isDirectory, !hit.node.isPackage, !hit.node.children.isEmpty {
                onZoomRequest?(hit.id)
            } else if let parent = hit.node.parent {
                onZoomRequest?(parent)
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = tile(at: point) else { return }
        onSelect?(hit.id)

        let menu = NSMenu()
        menu.addItem(withTitle: "Revelar en Finder", action: #selector(revealMenuAction(_:)), keyEquivalent: "").representedObject = hit.id
        menu.addItem(withTitle: "Abrir", action: #selector(openMenuAction(_:)), keyEquivalent: "").representedObject = hit.id
        menu.addItem(.separator())
        menu.addItem(withTitle: "Mover a la Papelera", action: #selector(trashMenuAction(_:)), keyEquivalent: "").representedObject = hit.id
        menu.addItem(withTitle: "Eliminar…", action: #selector(deleteMenuAction(_:)), keyEquivalent: "").representedObject = hit.id
        for item in menu.items { item.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func revealMenuAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? NodeID else { return }
        onReveal?(id)
    }

    @objc private func openMenuAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? NodeID else { return }
        onOpen?(id)
    }

    @objc private func trashMenuAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? NodeID else { return }
        onTrash?(id)
    }

    @objc private func deleteMenuAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? NodeID else { return }
        onDelete?(id)
    }
}
