import EdgyCore
import EdgyRuntime
import SwiftUI

/// The inspector for the selected zone: name, Split into, mapped gestures, Add gesture…, parameter rows, notes (bones 6–7, § Binding parameters, § App profiles rows).
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct InspectorView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("InspectorView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
