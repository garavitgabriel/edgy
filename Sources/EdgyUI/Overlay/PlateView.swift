import EdgyCore
import SwiftUI

/// The ONE plate component (bone 9): Test Mode overlay plates, the level plate, the display check
/// and onboarding feedback all use it — same radius, same 17/13 type pair, same inset.
///
/// It follows the environment's appearance and reads only `Tokens`. The overlay's panels draw it
/// dark (renders D and S8: a dark plate reads over light and dark documents alike); onboarding
/// draws it on its own light glass.
public struct PlateView: View {
  public enum Mark: Hashable, Sendable {
    /// Filled accent contact: recognized.
    case recognized
    /// A 2 pt accent outline, no fill: recognized in dry run, nothing ran (BRIEF § Test Mode).
    /// Told apart from `rejected` by colour role and by the strike.
    case wouldRun
    /// Hollow, struck circle: rejected.
    case rejected
    /// A level bar 0...1 (level plate).
    case level(Double)
    case none
  }

  /// A text button on the one clickable plate (the display check).
  public struct Button: Identifiable {
    public var id: String { title }
    public var title: String
    public var action: @MainActor () -> Void

    public init(_ title: String, action: @escaping @MainActor () -> Void) {
      self.title = title
      self.action = action
    }
  }

  public var mark: Mark
  /// 17 pt line ("Volume 64%"), or the single 13 pt line when `detail` is nil.
  public var title: String
  /// 13 pt line ("Right edge, slide").
  public var detail: String?
  /// Buttons under the line (display check only). A plate with buttons is a question: its line
  /// is 13 semibold.
  public var buttons: [Button]

  public init(mark: Mark, title: String, detail: String? = nil) {
    self.init(mark: mark, title: title, detail: detail, buttons: [])
  }

  public init(mark: Mark, title: String, detail: String? = nil, buttons: [Button]) {
    self.mark = mark
    self.title = title
    self.detail = detail
    self.buttons = buttons
  }

  public var body: some View {
    HStack(alignment: .center, spacing: PlateMetrics.markGap) {
      if let markShape { markShape.frame(width: PlateMetrics.mark, height: PlateMetrics.mark) }
      VStack(alignment: .leading, spacing: PlateMetrics.lineGap) {
        titleText
        if let detail {
          Text(detail).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
        }
        if case .level(let level) = mark { LevelBar(level: level) }
        if !buttons.isEmpty {
          VStack(alignment: .leading, spacing: PlateMetrics.buttonGap) {
            ForEach(buttons) { button in
              SwiftUI.Button(button.title, action: button.action).buttonStyle(PlateButtonStyle())
            }
          }
          .padding(.top, PlateMetrics.lineGap)
        }
      }
      .fixedSize()
    }
    .padding(.horizontal, PlateMetrics.insetH)
    .padding(.vertical, PlateMetrics.insetV)
    .frame(minWidth: isLevel ? PlateMetrics.levelWidth : nil, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: Tokens.radiusPlate, style: .continuous)
        .fill(Tokens.windowTint.opacity(Tokens.windowTintOpacity))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Tokens.radiusPlate, style: .continuous)
        .strokeBorder(Tokens.line.opacity(PlateMetrics.edgeOpacity), lineWidth: PlateMetrics.hairline)
    )
    .accessibilityElement(children: buttons.isEmpty ? .combine : .contain)
    .accessibilityLabel([title, detail].compactMap(\.self).joined(separator: ", "))
  }

  private var isLevel: Bool {
    if case .level = mark { return true }
    return false
  }

  @ViewBuilder private var titleText: some View {
    if !buttons.isEmpty {
      Text(title).font(Tokens.font(Tokens.typeBody, semibold: true)).foregroundStyle(Tokens.ink)
    } else if detail == nil && !isLevel {
      Text(title).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
    } else {
      Text(title).font(Tokens.font(Tokens.typeValue, semibold: true)).foregroundStyle(Tokens.ink)
    }
  }

  private var markShape: AnyView? {
    switch mark {
    case .recognized:
      return AnyView(Circle().fill(Tokens.accent))
    case .wouldRun:
      return AnyView(
        Circle().strokeBorder(Tokens.accent, lineWidth: PlateMetrics.wouldRunStroke))
    case .rejected:
      return AnyView(StruckCircle().stroke(Tokens.ink2, lineWidth: PlateMetrics.rejectedStroke))
    case .level, .none:
      return nil
    }
  }
}

/// Plate layout numbers (not type, colour or radius: those live in `Tokens`).
enum PlateMetrics {
  static let insetH: CGFloat = 18
  static let insetV: CGFloat = 14
  static let mark: CGFloat = 26
  static let markGap: CGFloat = 14
  static let lineGap: CGFloat = 2
  static let buttonGap: CGFloat = 8
  static let wouldRunStroke: CGFloat = 2
  static let rejectedStroke: CGFloat = 1.5
  static let hairline: CGFloat = 1
  static let edgeOpacity = 0.35
  static let levelWidth: CGFloat = 220
  static let levelBarHeight: CGFloat = 4
  static let levelBarTop: CGFloat = 8
  static let buttonPadH: CGFloat = 12
  static let buttonPadV: CGFloat = 5
  static let buttonWash = 0.12
  static let buttonWashPressed = 0.22
  static let trackOpacity = 0.45
}

/// The hollow circle with a strike (rejected): the strike runs bottom-left to top-right, inside.
struct StruckCircle: Shape {
  func path(in rect: CGRect) -> Path {
    let inset = rect.insetBy(dx: PlateMetrics.rejectedStroke / 2, dy: PlateMetrics.rejectedStroke / 2)
    var path = Path(ellipseIn: inset)
    let r = inset.width / 2
    let d = r * 0.7071
    path.move(to: CGPoint(x: inset.midX - d, y: inset.midY + d))
    path.addLine(to: CGPoint(x: inset.midX + d, y: inset.midY - d))
    return path
  }
}

/// The level plate's slim accent bar.
struct LevelBar: View {
  var level: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Tokens.line.opacity(PlateMetrics.trackOpacity))
        Capsule().fill(Tokens.accent).frame(width: proxy.size.width * min(max(level, 0), 1))
      }
    }
    .frame(width: PlateMetrics.levelWidth - 2 * PlateMetrics.insetH, height: PlateMetrics.levelBarHeight)
    .padding(.top, PlateMetrics.levelBarTop)
    .accessibilityHidden(true)
  }
}

/// The display check's text buttons: `ink` text on a 12% `ink` wash, control radius.
struct PlateButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.font(Tokens.typeBody))
      .foregroundStyle(Tokens.ink)
      .padding(.horizontal, PlateMetrics.buttonPadH)
      .padding(.vertical, PlateMetrics.buttonPadV)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl, style: .continuous)
          .fill(Tokens.ink.opacity(configuration.isPressed ? PlateMetrics.buttonWashPressed : PlateMetrics.buttonWash))
      )
      .contentShape(Rectangle())
  }
}

extension PlateView {
  /// The plate for one content value; the display check gets its two answers.
  init(_ content: PlateContent, onAnswer: (@MainActor (Bool) -> Void)? = nil) {
    if content.isDisplayCheck, let onAnswer {
      self.init(
        mark: .none, title: content.title,
        buttons: [
          Button(PlateContent.displayCheckYes) { onAnswer(true) },
          Button(PlateContent.displayCheckNo) { onAnswer(false) },
        ])
    } else {
      self.init(mark: content.mark, title: content.title, detail: content.detail)
    }
  }
}
