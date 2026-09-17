/// An item to be laid out by `SquarifiedTreemapLayout`. `weight` is whatever size
/// metric drives tile area (aggregate logical or allocated size) — the algorithm
/// itself is agnostic to what it represents.
public struct TreemapLayoutNode: Sendable {
    public let id: NodeID
    public let weight: Double

    public init(id: NodeID, weight: Double) {
        self.id = id
        self.weight = weight
    }
}
