import EdgyCore
import EdgyRuntime
import SwiftUI

/// The action picker popover content for `model.picking` (bone 5, § Picker at catalog scale).
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct ActionPickerView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("ActionPickerView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
