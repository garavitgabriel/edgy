import Foundation

/// An external audio/video service, paired with the display attributes that precede it.
struct AVServiceCandidate: Sendable {
  var attributes: ProductAttributes?
  var transport: (any DDCTransport)?
}

enum AVServiceMatching {
  /// Pairs each external AV service with the most recent display attributes seen before it in
  /// registry order (a framebuffer is listed ahead of the services beneath it). Each attribute
  /// set is used once; internal (built-in) services are skipped and consume their attributes.
  static func candidates(from nodes: [RegistryNode]) -> [AVServiceCandidate] {
    var lastAttributes: ProductAttributes?
    var result: [AVServiceCandidate] = []
    for node in nodes {
      switch node {
      case .display(let attributes):
        lastAttributes = attributes
      case .avService(let external, let transport):
        if external { result.append(AVServiceCandidate(attributes: lastAttributes, transport: transport)) }
        lastAttributes = nil
      }
    }
    return result
  }

  /// Assigns candidates to displays: first by vendor + product + serial, then vendor + product in
  /// order (serials are often zero, and two identical monitors share everything else), then any
  /// attribute-less candidate in order. Returns display ID → candidate index.
  static func assign(displays: [DisplayDescriptor], candidates: [AVServiceCandidate]) -> [UInt32: Int] {
    var assigned: [UInt32: Int] = [:]
    var used = Set<Int>()

    func pass(_ matches: (DisplayDescriptor, ProductAttributes?) -> Bool) {
      for display in displays where assigned[display.id] == nil {
        let index = candidates.indices.first { !used.contains($0) && matches(display, candidates[$0].attributes) }
        if let index {
          assigned[display.id] = index
          used.insert(index)
        }
      }
    }

    pass { display, attributes in
      guard let attributes, display.serial != 0 else { return false }
      return attributes.vendorID == display.vendorID && attributes.productID == display.productID
        && attributes.serial == display.serial
    }
    pass { display, attributes in
      guard let attributes else { return false }
      return attributes.vendorID == display.vendorID && attributes.productID == display.productID
    }
    pass { _, attributes in attributes == nil }
    return assigned
  }
}
