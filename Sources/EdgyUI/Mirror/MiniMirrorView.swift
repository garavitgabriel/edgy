import EdgyCore
import EdgyRuntime
import SwiftUI

/// The popover's mini mirror: zones of the active profile and the last touch where it landed (bone 10).
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct MiniMirrorView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("MiniMirrorView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
