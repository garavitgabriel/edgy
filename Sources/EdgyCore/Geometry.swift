/// Plain value geometry so EdgyCore stays free of CoreGraphics and fully Hashable/Codable.
public struct Point2D: Codable, Hashable, Sendable {
  public var x: Double
  public var y: Double
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public struct Vector2D: Codable, Hashable, Sendable {
  public var dx: Double
  public var dy: Double
  public init(dx: Double, dy: Double) {
    self.dx = dx
    self.dy = dy
  }
}

public struct Size2D: Codable, Hashable, Sendable {
  public var width: Double
  public var height: Double
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}
