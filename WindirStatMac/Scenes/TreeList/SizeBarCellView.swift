// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

/// Draws a thin horizontal bar filled proportionally to `fraction` (0...1),
/// mirroring the original app's inline size-bar column.
final class SizeBarView: NSView {
    var fraction: Double = 0 {
        didSet { needsDisplay = true }
    }
    var tintColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let trackRect = bounds.insetBy(dx: 0, dy: bounds.height * 0.3)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: 2, yRadius: 2)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.3).setFill()
        track.fill()

        guard fraction > 0 else { return }
        var fillRect = trackRect
        fillRect.size.width = max(2, trackRect.width * CGFloat(min(fraction, 1)))
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
        tintColor.setFill()
        fillPath.fill()
    }
}

/// A `Name` column cell: disclosure-driven icon + name label (icon/label are
/// standard `NSTableCellView` machinery; this just adds the icon and label as
/// subviews without a nib).
final class NameCellView: NSTableCellView {
    let iconView = NSImageView()
    let nameLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(iconView)
        addSubview(nameLabel)
        imageView = iconView
        textField = nameLabel

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

/// A `Size` column cell: right-aligned size text over the inline bar.
final class SizeCellView: NSTableCellView {
    let sizeLabel = NSTextField(labelWithString: "")
    let barView = SizeBarView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.alignment = .right
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        barView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(barView)
        addSubview(sizeLabel)
        textField = sizeLabel

        NSLayoutConstraint.activate([
            sizeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeLabel.widthAnchor.constraint(equalToConstant: 84),
            barView.leadingAnchor.constraint(equalTo: leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: sizeLabel.leadingAnchor, constant: -6),
            barView.centerYAnchor.constraint(equalTo: centerYAnchor),
            barView.heightAnchor.constraint(equalToConstant: 12),
        ])
    }
}
