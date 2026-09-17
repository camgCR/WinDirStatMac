// SPDX-License-Identifier: GPL-2.0-or-later
/// The "squarified" treemap layout algorithm (Bruls, Huizing, van Wijk, 2000),
/// reimplemented fresh here — not ported from any existing codebase. Lays out a
/// single directory level's children into tiles whose aspect ratios stay as close
/// to square as possible, which is what makes treemaps of this family legible
/// compared to naive slice-and-dice layouts.
public enum SquarifiedTreemapLayout {
    /// Lays out `items` (any weight metric — callers pass aggregate logical or
    /// allocated size) to tile `bounds`. Items are sorted descending by weight
    /// internally; zero-weight items and non-positive bounds produce no rects.
    public static func layout(items: [TreemapLayoutNode], in bounds: TreemapRect) -> [NodeID: TreemapRect] {
        guard !items.isEmpty, bounds.width > 0, bounds.height > 0 else { return [:] }
        let totalWeight = items.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return [:] }

        let scale = bounds.area / totalWeight
        let sorted = items
            .sorted { $0.weight > $1.weight }
            .map { (id: $0.id, area: $0.weight * scale) }
            .filter { $0.area > 0 }
        guard !sorted.isEmpty else { return [:] }

        var result: [NodeID: TreemapRect] = [:]
        var currentBounds = bounds
        var index = 0
        let count = sorted.count

        while index < count {
            let shorterSide = min(currentBounds.width, currentBounds.height)
            var rowAreas: [Double] = [sorted[index].area]
            var rowEnd = index + 1
            var bestRatio = worstAspectRatio(rowAreas: rowAreas, length: shorterSide)

            while rowEnd < count {
                let candidateAreas = rowAreas + [sorted[rowEnd].area]
                let candidateRatio = worstAspectRatio(rowAreas: candidateAreas, length: shorterSide)
                guard candidateRatio <= bestRatio else { break }
                rowAreas = candidateAreas
                bestRatio = candidateRatio
                rowEnd += 1
            }

            let (rects, remaining) = layoutRow(areas: rowAreas, bounds: currentBounds)
            for (offset, rect) in rects.enumerated() {
                result[sorted[index + offset].id] = rect
            }
            currentBounds = remaining
            index = rowEnd
        }

        return result
    }

    /// Returns the id of the topmost tile containing `(x, y)`, if any.
    public static func hitTest(x: Double, y: Double, in layout: [NodeID: TreemapRect]) -> NodeID? {
        for (id, rect) in layout where rect.contains(x: x, y: y) {
            return id
        }
        return nil
    }

    /// Worst aspect ratio among a candidate row, per the paper's formula:
    /// `max((L² · maxArea) / S², S² / (L² · minArea))`, where `S` is the row's
    /// total area and `L` is the length of the side the row is laid out along.
    private static func worstAspectRatio(rowAreas: [Double], length: Double) -> Double {
        guard let maxArea = rowAreas.max(), let minArea = rowAreas.min(), minArea > 0, length > 0 else {
            return .infinity
        }
        let sum = rowAreas.reduce(0, +)
        let lengthSquared = length * length
        let sumSquared = sum * sum
        return max((lengthSquared * maxArea) / sumSquared, sumSquared / (lengthSquared * minArea))
    }

    /// Places a row of items (given as raw areas, already known to fit exactly
    /// along the bounds' shorter side) and returns the remaining bounds after
    /// slicing off the strip they occupied.
    private static func layoutRow(areas: [Double], bounds: TreemapRect) -> (rects: [TreemapRect], remaining: TreemapRect) {
        let rowSum = areas.reduce(0, +)
        guard rowSum > 0 else { return ([], bounds) }

        if bounds.width <= bounds.height {
            let stripHeight = rowSum / bounds.width
            var x = bounds.x
            var rects: [TreemapRect] = []
            for area in areas {
                let width = area / stripHeight
                rects.append(TreemapRect(x: x, y: bounds.y, width: width, height: stripHeight))
                x += width
            }
            let remaining = TreemapRect(x: bounds.x, y: bounds.y + stripHeight, width: bounds.width, height: bounds.height - stripHeight)
            return (rects, remaining)
        } else {
            let stripWidth = rowSum / bounds.height
            var y = bounds.y
            var rects: [TreemapRect] = []
            for area in areas {
                let height = area / stripWidth
                rects.append(TreemapRect(x: bounds.x, y: y, width: stripWidth, height: height))
                y += height
            }
            let remaining = TreemapRect(x: bounds.x + stripWidth, y: bounds.y, width: bounds.width - stripWidth, height: bounds.height)
            return (rects, remaining)
        }
    }
}
