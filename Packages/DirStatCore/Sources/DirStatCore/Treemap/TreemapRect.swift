public struct TreemapRect: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var area: Double { width * height }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }
}
