import EdgyCore
import EdgyRuntime
import SwiftUI

/// The menu-bar popover: mini mirror, profile chips, Enabled + Test Mode, plain list (bone 10, § System states).
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct MenuPopoverView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("MenuPopoverView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
