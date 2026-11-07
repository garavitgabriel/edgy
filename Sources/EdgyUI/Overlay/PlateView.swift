import EdgyCore
import SwiftUI

/// The ONE plate component (bone 9): Test Mode overlay plates, the level plate, the display check
/// and onboarding feedback all use it — same radius, same 17/13 type pair, same inset.
///
/// Skeleton (chief). The popover/overlay batch owns the drawing; the content enum is the contract
/// other batches compose against.
public struct PlateView: View {
  public enum Mark: Hashable, Sendable {
    /// Filled accent contact: recognized.
    case recognized
    /// Hollow, struck circle: rejected.
    case rejected
    /// A level bar 0...1 (level plate).
    case level(Double)
    case none
  }

  public var mark: Mark
  /// 17 pt line ("Volume 64%"), or the single 13 pt line when `detail` is nil.
  public var title: String
  /// 13 pt line ("Right edge, slide").
  public var detail: String?

  public init(mark: Mark, title: String, detail: String? = nil) {
    self.mark = mark
    self.title = title
    self.detail = detail
  }

  public var body: some View {
    Text(title).font(Tokens.font(Tokens.typeValue)).foregroundStyle(Tokens.ink)
  }
}
