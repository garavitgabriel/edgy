import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Observation

// MARK: - Split

/// How "Split into N" moves an edge's bindings (bone 6: the runtime allows 1…4 segments).
///
/// **Rule:** each new segment takes the bindings of the old segment under its centre. So
/// splitting copies (1 → 2: both halves do what the whole edge did, nothing changes under the
/// finger), and merging keeps the binding at the middle of the edge. Bindings on other zones are
/// untouched. The whole change is one undo step.
enum SplitPlan {
  /// The bindings of `edge` in `bindings`, re-laid on `segments` parts.
  static func remap(_ bindings: [Binding], edge: Zone.Edge, to segments: Int) -> [Binding] {
    var result: [Binding] = []
    for target in 0..<segments {
      let centre = (Double(target) + 0.5) / Double(segments)
      for binding in bindings {
        guard case .edge(let e, let segment, let count) = binding.zone, e == edge, count > 0 else { continue }
        guard Int(centre * Double(count)) == segment else { continue }
        var moved = binding
        moved.zone = .edge(edge, segment: target, segments: segments)
        guard !result.contains(where: { $0.key == moved.key }) else { continue }
        result.append(moved)
      }
    }
    return result
  }

  /// The segment that holds the selected segment's centre after the split.
  static func selection(after zone: Zone, segments: Int) -> Zone {
    guard case .edge(let edge, let segment, let count) = zone, count > 0 else { return zone }
    let centre = (Double(segment) + 0.5) / Double(count)
    return .edge(edge, segment: min(Int(centre * Double(segments)), segments - 1), segments: segments)
  }
}

// MARK: - Drafts

/// A binding the user chose but can't be saved yet: an action whose required parameter is still
/// empty (the editor refuses a binding with an error). Its row reads "Needs keys" until the field
/// is filled, then it is written and the draft goes away.
///
/// The frozen `SettingsModel` has no field for this, and the picker and inspector are siblings, so
/// drafts live in a per-model side table here (see `.parallel-plans/blockers-batch-15.md`).
@MainActor
@Observable
final class InspectorDrafts {
  struct Key: Hashable {
    var profile: ProfileRef
    var binding: BindingKey
  }

  var drafts: [Key: Binding] = [:]
  /// The field to focus when the inspector next draws (the picker hands off to it).
  var focus: Key?
  /// The row whose "…" menu is open (a note's fix can open it).
  var openMenu: BindingKey?

  private static let table = NSMapTable<SettingsModel, InspectorDrafts>.weakToStrongObjects()

  static func of(_ model: SettingsModel) -> InspectorDrafts {
    if let drafts = table.object(forKey: model) { return drafts }
    let drafts = InspectorDrafts()
    table.setObject(drafts, forKey: model)
    return drafts
  }
}

// MARK: - Rows

/// One binding row in the inspector.
struct InspectorRow: Identifiable, Equatable {
  var binding: Binding
  /// `nil` on the Default tab (and in full-replace app profiles' plain rows).
  var source: EffectiveBinding.Source?
  var defaultBinding: Binding?
  /// The row is a draft: chosen, not saved, waiting for a required parameter.
  var isDraft = false

  var id: BindingKey { binding.key }
  var gesture: GestureKind { binding.gesture }

  /// Parameter rows show for bindings this tab owns: not for an inherited row (it is Default's)
  /// nor a turned-off one (nothing runs).
  var showsParameters: Bool { source != .inherited && source != .turnedOff }
}

extension SettingsModel {
  /// The profile edits go to and rows read from.
  var inspectorProfile: ProfileRef { selectedProfile }

  var inspectorDrafts: InspectorDrafts { InspectorDrafts.of(self) }

  /// Only the mapped gestures of `zone` (bone 6), in gesture display order, with drafts on top of
  /// their slot. On an app tab the rows come from `effectiveBindings` with their source.
  func inspectorRows(for zone: Zone) -> [InspectorRow] {
    _ = revision
    var rows: [InspectorRow]
    switch inspectorProfile {
    case .default:
      rows = editor.bindingsByZone(in: .default).first { $0.zone == zone }?.bindings
        .filter { $0.action != .doNothing }
        .map { InspectorRow(binding: $0, source: nil) } ?? []
    case .app(let bundleID):
      rows = editor.effectiveBindings(forApp: bundleID).filter { $0.binding.zone == zone }.map {
        InspectorRow(binding: $0.binding, source: $0.source, defaultBinding: $0.defaultBinding)
      }
    }
    for (key, draft) in inspectorDrafts.drafts where key.profile == inspectorProfile && key.binding.zone == zone {
      if let index = rows.firstIndex(where: { $0.id == key.binding }) {
        rows[index].binding = draft
        rows[index].isDraft = true
        if rows[index].source == .inherited || rows[index].source == .turnedOff { rows[index].source = .overridden }
      } else {
        let source: EffectiveBinding.Source? = inspectorProfile == .default ? nil : .appOnly
        rows.append(InspectorRow(binding: draft, source: source, isDraft: true))
      }
    }
    let order = GestureKind.all
    return rows.sorted { (order.firstIndex(of: $0.gesture) ?? 99) < (order.firstIndex(of: $1.gesture) ?? 99) }
  }

  /// Gestures `zone` can take that have no row yet ("Add gesture…" offers these).
  func unmappedGestures(for zone: Zone) -> [GestureKind] {
    let mapped = Set(inspectorRows(for: zone).filter { $0.source != .turnedOff }.map(\.gesture))
    return editor.supportedGestures(for: zone).filter { !mapped.contains($0) }
  }

  /// Issues of the open profile attached to `key`.
  func inspectorIssues(for key: BindingKey) -> [ValidationIssue] {
    _ = revision
    return editor.issues.filter { $0.binding == key && ($0.profile ?? .default) == inspectorProfile }
  }

  /// `overlappingZones` warnings on this edge, as (zone, other zone, gesture).
  func overlaps(onEdgeOf zone: Zone) -> [(Zone, Zone, GestureKind)] {
    _ = revision
    guard case .edge(let edge, _, _) = zone else { return [] }
    let bindings: [Binding]
    switch inspectorProfile {
    case .default: bindings = editor.config.defaultProfile.bindings
    case .app(let id): bindings = editor.effectiveBindings(forApp: id).map(\.binding)
    }
    var found: [(Zone, Zone, GestureKind)] = []
    let onEdge = bindings.filter {
      if case .edge(edge, _, _) = $0.zone, $0.action != .doNothing { return true }
      return false
    }
    for (index, a) in onEdge.enumerated() {
      for b in onEdge[(index + 1)...] where ConfigValidator.overlaps(a, b) {
        let (wide, narrow) = segmentsOf(a.zone) <= segmentsOf(b.zone) ? (a.zone, b.zone) : (b.zone, a.zone)
        found.append((wide, narrow, a.gesture))
      }
    }
    return found
  }

  private func segmentsOf(_ zone: Zone) -> Int {
    if case .edge(_, _, let count) = zone { return count }
    return 0
  }

  /// Segments of the selected edge (1 when whole), `nil` for a corner.
  func splitCount(for zone: Zone) -> Int? {
    guard case .edge(_, _, let count) = zone else { return nil }
    return count
  }

  /// Split lives in bindings; an inheriting app tab follows Default's layout.
  var canSplit: Bool {
    guard case .app(let id) = inspectorProfile else { return true }
    return editor.config.appProfiles[id]?.inheritsDefault == false
  }
}

// MARK: - Writes (all through `editor`)

extension SettingsModel {
  /// Writes `binding` to the open profile: `setBinding` on Default; on an app tab an override, or a
  /// revert when it equals Default's binding. Throws the editor's error (nothing changed).
  func writeBinding(_ binding: Binding, replacing previous: BindingKey? = nil) throws {
    switch inspectorProfile {
    case .default:
      try editor.setBinding(binding, in: .default, replacing: previous)
    case .app(let bundleID):
      let inherits = editor.config.appProfiles[bundleID]?.inheritsDefault ?? true
      let base = editor.config.defaultProfile.bindings.first { $0.key == binding.key }
      if inherits, let base, base == binding {
        try editor.revertToDefault(binding.key, forApp: bundleID)
      } else if binding.action == .doNothing, inherits {
        try editor.turnOff(binding.key, forApp: bundleID)
      } else {
        try editor.overrideBinding(binding, forApp: bundleID)
      }
      if let previous, previous != binding.key { try editor.revertToDefault(previous, forApp: bundleID) }
    }
  }

  /// The picker's choice for `zone` + `gesture`. Actions with an empty required parameter become
  /// a draft (written once filled); the picker closes and the first field gets focus.
  func choose(_ action: ActionID, zone: Zone, gesture: GestureKind) {
    let key = BindingKey(zone: zone, gesture: gesture)
    let draftKey = InspectorDrafts.Key(profile: inspectorProfile, binding: key)
    let existing = inspectorRows(for: zone).first { $0.id == key }
    var binding = Binding(zone: zone, gesture: gesture, action: action)
    if let existing, existing.binding.action == action, existing.source != .turnedOff {
      binding.parameters = existing.binding.parameters
    } else if let haptics = existing?.binding.parameters[AppSettings.hapticsParameter] {
      binding.parameters[AppSettings.hapticsParameter] = haptics
    }
    inspectorDrafts.drafts[draftKey] = nil
    picking = nil
    let descriptor = editor.validator.descriptor(for: action)
    if let descriptor, !descriptor.parameters.isEmpty { inspectorDrafts.focus = draftKey }
    if needsParameters(binding) {
      inspectorDrafts.drafts[draftKey] = binding
      return
    }
    try? writeBinding(binding)
  }

  /// True when a required parameter of `binding`'s action is empty.
  func needsParameters(_ binding: Binding) -> Bool {
    guard let descriptor = editor.validator.descriptor(for: binding.action) else { return false }
    return descriptor.parameters.contains {
      $0.required && (binding.parameters[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
  }

  /// Sets (or clears, with `nil`) one parameter of a row. Returns the blocking error's issue, if
  /// any; the edit then doesn't apply and the control keeps the user's input.
  @discardableResult
  func setParameter(_ key: String, to value: String?, in staleRow: InspectorRow) -> ValidationIssue? {
    // Controls capture their row when drawn; edit the slot as it is now.
    let row = inspectorRows(for: staleRow.binding.zone).first { $0.id == staleRow.id } ?? staleRow
    var binding = row.binding
    binding.parameters[key] = value
    let draftKey = InspectorDrafts.Key(profile: inspectorProfile, binding: row.id)
    let errors = editor.validate(binding, in: inspectorProfile).filter(\.isError)
    if let blocking = errors.first(where: { $0.parameter == key && $0.code != .missingParameter }) {
      return blocking
    }
    if needsParameters(binding) {
      // Still incomplete: keep it as a draft. A saved binding losing a required value leaves the
      // slot off (nothing fires) while the row reads "Needs keys".
      if !row.isDraft { clearSlot(row) }
      inspectorDrafts.drafts[draftKey] = binding
      return nil
    }
    if let error = errors.first { return error }
    do {
      try writeBinding(binding)
      inspectorDrafts.drafts[draftKey] = nil
      return nil
    } catch SettingsEditorError.invalid(let issues) {
      return issues.first
    } catch {
      return nil
    }
  }

  private func clearSlot(_ row: InspectorRow) {
    switch inspectorProfile {
    case .default: try? editor.removeBinding(row.id, from: .default)
    case .app(let id):
      if row.defaultBinding != nil { try? editor.turnOff(row.id, forApp: id) } else {
        try? editor.revertToDefault(row.id, forApp: id)
      }
    }
  }

  /// "…" menu and Revert actions.
  func revert(_ row: InspectorRow) {
    inspectorDrafts.drafts[InspectorDrafts.Key(profile: inspectorProfile, binding: row.id)] = nil
    guard case .app(let id) = inspectorProfile else { return }
    try? editor.revertToDefault(row.id, forApp: id)
  }

  func turnOff(_ row: InspectorRow) {
    inspectorDrafts.drafts[InspectorDrafts.Key(profile: inspectorProfile, binding: row.id)] = nil
    guard case .app(let id) = inspectorProfile else { return }
    try? editor.turnOff(row.id, forApp: id)
  }

  /// Default tab's "Remove gesture".
  func remove(_ row: InspectorRow) {
    inspectorDrafts.drafts[InspectorDrafts.Key(profile: inspectorProfile, binding: row.id)] = nil
    switch inspectorProfile {
    case .default: try? editor.removeBinding(row.id, from: .default)
    case .app(let id): try? editor.revertToDefault(row.id, forApp: id)
    }
  }

  /// Bone 7's one fix: the tap moves to the long-press slot (the double-tap no longer waits).
  func useLongPressInstead(for tap: BindingKey) {
    guard let row = inspectorRows(for: tap.zone).first(where: { $0.id == tap }) else { return }
    var moved = row.binding
    moved.gesture = .longPress
    try? writeBinding(moved, replacing: tap)
  }

  /// "Split into N": re-lays the selected edge's bindings (see `SplitPlan`) as one undo step and
  /// keeps the selection on the part under the old one.
  func split(_ zone: Zone, into segments: Int) {
    guard case .edge(let edge, _, let count) = zone, count != segments,
      ConfigValidator.segmentCounts.contains(segments), canSplit
    else { return }
    let ref = inspectorProfile
    let current = editor.profile(ref)?.bindings ?? []
    let onEdge = current.filter {
      if case .edge(edge, _, _) = $0.zone { return true }
      return false
    }
    let remapped = SplitPlan.remap(onEdge, edge: edge, to: segments)
    editor.beginContinuousEdit("split")
    for binding in onEdge { try? editor.removeBinding(binding.key, from: ref) }
    for binding in remapped { try? editor.setBinding(binding, in: ref) }
    try? editor.endContinuousEdit()
    selectedZone = SplitPlan.selection(after: zone, segments: segments)
  }
}
