// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct TreemapLayoutTests {
    private func node(_ raw: Int32) -> NodeID { NodeID(rawValue: raw) }

    @Test func emptyInputProducesNoRects() {
        let result = SquarifiedTreemapLayout.layout(items: [], in: TreemapRect(x: 0, y: 0, width: 100, height: 100))
        #expect(result.isEmpty)
    }

    @Test func zeroSizedBoundsProducesNoRects() {
        let items = [TreemapLayoutNode(id: node(0), weight: 10)]
        let result = SquarifiedTreemapLayout.layout(items: items, in: TreemapRect(x: 0, y: 0, width: 0, height: 100))
        #expect(result.isEmpty)
    }

    @Test func singleItemFillsTheEntireBounds() throws {
        let bounds = TreemapRect(x: 0, y: 0, width: 200, height: 100)
        let result = SquarifiedTreemapLayout.layout(items: [TreemapLayoutNode(id: node(0), weight: 42)], in: bounds)
        let rect = try #require(result[node(0)])
        #expect(abs(rect.area - bounds.area) < 0.001)
        #expect(abs(rect.width - bounds.width) < 0.001)
        #expect(abs(rect.height - bounds.height) < 0.001)
    }

    @Test func tilesExactlyPartitionTheBoundsWithNoGapsOrOverlaps() throws {
        let bounds = TreemapRect(x: 0, y: 0, width: 300, height: 150)
        let items: [TreemapLayoutNode] = (0..<12).map { index -> TreemapLayoutNode in
            let side: Int = index + 1
            let weight: Double = Double(side * side)
            return TreemapLayoutNode(id: node(Int32(index)), weight: weight)
        }
        let result = SquarifiedTreemapLayout.layout(items: items, in: bounds)

        #expect(result.count == items.count)

        let totalArea = result.values.reduce(0.0) { $0 + $1.area }
        #expect(abs(totalArea - bounds.area) < 0.01)

        // Each tile's own area should be proportional to its weight.
        let totalWeight = items.reduce(0.0) { $0 + $1.weight }
        for item in items {
            let rect = try #require(result[item.id])
            let expectedArea = (item.weight / totalWeight) * bounds.area
            #expect(abs(rect.area - expectedArea) < 0.5)
        }

        // No tile should extend outside the bounds.
        for rect in result.values {
            #expect(rect.x >= bounds.x - 0.001)
            #expect(rect.y >= bounds.y - 0.001)
            #expect(rect.x + rect.width <= bounds.x + bounds.width + 0.001)
            #expect(rect.y + rect.height <= bounds.y + bounds.height + 0.001)
        }
    }

    @Test func squarifiedLayoutImprovesAspectRatioOverNaiveSliceAndDice() {
        // A classic skewed dataset (large disparity in weights) where naive
        // left-to-right slicing produces very thin slivers; squarifying should not.
        let bounds = TreemapRect(x: 0, y: 0, width: 400, height: 100)
        let weights: [Double] = [500, 300, 200, 100, 50, 30, 20]
        let items = weights.enumerated().map { TreemapLayoutNode(id: node(Int32($0.offset)), weight: $0.element) }
        let result = SquarifiedTreemapLayout.layout(items: items, in: bounds)

        func aspectRatio(_ rect: TreemapRect) -> Double {
            max(rect.width, rect.height) / max(min(rect.width, rect.height), 0.0001)
        }

        // Naive slice-and-dice along the width would give the smallest item
        // (weight 20 of total 1200) a width of 400 * 20/1200 ≈ 6.7 against height
        // 100 — an aspect ratio around 15. Squarifying should do much better.
        let worstSquarified = result.values.map(aspectRatio).max() ?? .infinity
        #expect(worstSquarified < 10)
    }

    @Test func hitTestFindsTheTileContainingAPoint() throws {
        let bounds = TreemapRect(x: 0, y: 0, width: 100, height: 100)
        let items = [
            TreemapLayoutNode(id: node(0), weight: 70),
            TreemapLayoutNode(id: node(1), weight: 30),
        ]
        let result = SquarifiedTreemapLayout.layout(items: items, in: bounds)
        let rect0 = try #require(result[node(0)])

        let hit = SquarifiedTreemapLayout.hitTest(x: rect0.x + 1, y: rect0.y + 1, in: result)
        #expect(hit == node(0))

        let outside = SquarifiedTreemapLayout.hitTest(x: -10, y: -10, in: result)
        #expect(outside == nil)
    }
}
