import EdgyCore
import EdgyRuntime
import Foundation

/// What a binding keeps when the picker gives its slot a different action (batch 29, § Your own
/// name and icon): the user's own name stays; their own icon stays unless it is the new action's
/// own icon (then it is just the default, `nil`). A turned-off slot or "Do nothing here" keeps
/// neither. Pure.
///
/// A custom name carries only within the same binding (critique 29 design answer 6): on an
/// inherited row the new action creates an app override, which starts WITHOUT Default's name.
/// On a row that is already an override, the name set there carries.
@MainActor enum PickerChoice {
  static func carry(
    from old: Binding?, oldIsTurnedOff: Bool = false, oldIsInherited: Bool = false, into new: inout Binding,
    actionName: String?
  ) {
    guard let old, !oldIsTurnedOff, new.action != .doNothing else { return }
    new.customName = oldIsInherited ? nil : SettingsEditor.customName(old.customName, actionName: actionName)
    new.customIcon = old.customIcon == new.action ? nil : old.customIcon
  }
}
