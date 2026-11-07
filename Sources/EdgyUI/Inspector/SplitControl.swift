import EdgyCore
import EdgyRuntime
import Foundation
import Observation
import SwiftUI

// MARK: - Hover state

/// The Split control's hover, shared with the mirror (§ Split control: "hovering a segment
/// previews that split on the mirror"). `SettingsModel` is frozen, so it lives in a per-model side
/// table like `InspectorDrafts`; `PadMirrorView` reads `model.splitPreview.hover`.
@MainActor
@Observable
final class SplitPreview {
  struct Hover: Equatable {
    var edge: Zone.Edge
    var parts: Int
  }

  var hover: Hover?

  private static let table = NSMapTable<SettingsModel, SplitPreview>.weakToStrongObjects()

  static func of(_ model: SettingsModel) -> SplitPreview {
    if let preview = table.object(forKey: model) { return preview }
    let preview = SplitPreview()
    table.setObject(preview, forKey: model)
    return preview
  }
}

extension SettingsModel {
  var splitPreview: SplitPreview { SplitPreview.of(self) }
}

// MARK: - Names and the note

/// Segment names for the Split control and the inspector's per-segment headings, in reading order
/// (side edges top to bottom, top and bottom edges left to right; the runtime counts side edges
/// bottom to top).
enum SplitNaming {
  /// "Whole edge", "2 parts", "3 parts", "4 parts" (the segments' accessibility names).
  static func accessibilityName(parts: Int) -> String {
    parts <= 1 ? "Whole edge" : "\(parts) parts"
  }

  /// 13 semibold `ink2` heading: "Upper half", "Top third", "Left half", "Part 2".
  static func heading(edge: Zone.Edge, segment: Int, segments: Int) -> String {
    let side = edge == .left || edge == .right
    let reading = side ? segments - 1 - segment : segment
    let i = min(max(reading, 0), segments - 1)
    switch segments {
    case 1: return "Whole edge"
    case 2: return side ? ["Upper half", "Lower half"][i] : ["Left half", "Right half"][i]
    case 3:
      return side
        ? ["Top third", "Middle third", "Bottom third"][i] : ["Left third", "Middle third", "Right third"][i]
    default: return "Part \(i + 1)"
    }
  }

  /// The edge's segments in reading order.
  static func readingOrder(edge: Zone.Edge, segments: Int) -> [Zone] {
    let side = edge == .left || edge == .right
    let indices = Array(0..<segments)
    return (side ? indices.reversed() : indices).map { .edge(edge, segment: $0, segments: segments) }
  }

  /// The one-line info note shown before a split change takes effect, when it moves or drops
  /// bindings (§ Split control): what each new part ends up with under `SplitPlan` (the first part
  /// keeps the bindings), e.g. "Upper third keeps Volume; the other two start empty." `nil` when the edge has
  /// nothing mapped or the count doesn't change.
  static func note(
    bindings: [EdgyCore.Binding], edge: Zone.Edge, from count: Int, to parts: Int, name: (ActionID) -> String
  ) -> String? {
    let onEdge = bindings.filter {
      if case .edge(edge, _, _) = $0.zone, $0.action != .doNothing { return true }
      return false
    }
    guard parts != count, !onEdge.isEmpty else { return nil }
    let remapped = SplitPlan.remap(onEdge, edge: edge, to: parts)
    func names(_ list: [EdgyCore.Binding]) -> [String] {
      var seen: [String] = []
      for binding in list where !seen.contains(name(binding.action)) { seen.append(name(binding.action)) }
      return seen
    }
    let segments = readingOrder(edge: edge, segments: parts)
    let kept = segments.map { zone in names(remapped.filter { $0.zone == zone }) }
    let dropped = names(onEdge).filter { old in !kept.contains { $0.contains(old) } }
    var clauses: [String] = []
    if parts == 1 {
      if let first = kept.first, !first.isEmpty { clauses.append("The whole edge keeps \(joined(first))") }
    } else if let first = kept.first, !first.isEmpty, kept.allSatisfy({ $0 == first }) {
      let all = ["", "", "Both halves", "All three thirds", "All four parts"][min(parts, 4)]
      clauses.append("\(all) keep \(joined(first))")
    } else {
      var empty: [String] = []
      for (index, zone) in segments.enumerated() {
        guard case .edge(_, let segment, _) = zone else { continue }
        let heading = noteName(edge: edge, segment: segment, segments: parts)
        if kept[index].isEmpty {
          empty.append(heading)
        } else {
          clauses.append("\(heading) keeps \(joined(kept[index]))")
        }
      }
      if empty.count == 1 {
        clauses.append("\(empty[0]) starts empty")
      } else if empty.count > 1 {
        clauses.append(clauses.isEmpty ? "every part starts empty" : "the other \(spelled(empty.count)) start empty")
      }
    }
    // Later clauses that open with a part name ("lower half starts empty") go lowercase mid-sentence;
    // action names keep their catalog spelling.
    clauses = clauses.enumerated().map { $0 == 0 ? $1 : $1.prefix(1).lowercased() + $1.dropFirst() }
    if !dropped.isEmpty { clauses.append("\(joined(dropped)) \(dropped.count == 1 ? "is" : "are") dropped") }
    guard !clauses.isEmpty else { return nil }
    let sentence = clauses.joined(separator: "; ")
    return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
  }

  /// A part's name in the note: the zone's own words for halves and thirds ("Upper third",
  /// BRIEF § Split control's example), the heading for quarters ("Part 2").
  static func noteName(edge: Zone.Edge, segment: Int, segments: Int) -> String {
    guard segments == 2 || segments == 3 else { return heading(edge: edge, segment: segment, segments: segments) }
    let part = ZoneNaming.part(edge: edge, segment: segment, segments: segments)
    return part.prefix(1).uppercased() + part.dropFirst()
  }

  private static func joined(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
  }

  private static func spelled(_ n: Int) -> String {
    ["zero", "one", "two", "three", "four"][min(n, 4)]
  }
}

extension SettingsModel {
  /// The note for hovering `parts` on `zone`'s edge, from the open profile's bindings.
  func splitNote(for zone: Zone, parts: Int) -> String? {
    guard case .edge(let edge, _, let count) = zone else { return nil }
    let bindings = editor.profile(inspectorProfile)?.bindings ?? []
    return SplitNaming.note(bindings: bindings, edge: edge, from: count, to: parts) { actionName($0) }
  }
}

// MARK: - The control

/// The Split row (§ Split control, replaces "Split into 1 2 3 4"): the label "Split" (13, `ink2`)
/// and four edge diagrams as a segmented control: *this* edge in the pad's orientation, divided
/// into 1–4 parts, the selected one filled `ink`. Hover previews the split on the mirror; the info
/// note says what happens to bindings before the click. Changing it is one undo step.
struct SplitControl: View {
  @Bindable var model: SettingsModel
  var zone: Zone
  var enabled: Bool

  var body: some View {
    if case .edge(let edge, _, let count) = zone {
      let preview = model.splitPreview
      let hovered = preview.hover?.edge == edge ? preview.hover?.parts : nil
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          Text("Split").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
          HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { parts in
              SplitSegment(
                edge: edge, parts: parts, selected: parts == count, hovered: hovered == parts
              ) {
                preview.hover = nil
                model.split(zone, into: parts)
              } onHover: { inside in
                if inside {
                  preview.hover = SplitPreview.Hover(edge: edge, parts: parts)
                } else if preview.hover == SplitPreview.Hover(edge: edge, parts: parts) {
                  preview.hover = nil
                }
              }
            }
          }
          .padding(2)
          .background(RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(Tokens.ink.opacity(0.06)))
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Split")
        }
        .disabled(!enabled)
        if let hovered, hovered != count, let note = model.splitNote(for: zone, parts: hovered) {
          IssueLine(style: .info, text: note)
        }
      }
      .onDisappear {
        if preview.hover?.edge == edge { preview.hover = nil }
      }
    }
  }
}

/// One segment: the diagram on a quiet tile (raised when selected, the 10% `ink` wash on hover).
struct SplitSegment: View {
  var edge: Zone.Edge
  var parts: Int
  var selected: Bool
  var hovered: Bool
  var action: () -> Void
  var onHover: (Bool) -> Void

  var body: some View {
    let vertical = edge == .left || edge == .right
    Button(action: action) {
      EdgySplitGlyph(edge: edge, parts: parts, selected: selected)
        .padding(.horizontal, vertical ? 8 : 6).padding(.vertical, vertical ? 4 : 8)
        .background(
          RoundedRectangle(cornerRadius: Tokens.radiusControl - 1)
            .fill(selected ? Tokens.windowTint : Tokens.ink.opacity(hovered ? 0.1 : 0))
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover(perform: onHover)
    .accessibilityLabel(SplitNaming.accessibilityName(parts: parts))
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}
