import EdgyCore
import EdgyRuntime
import SwiftUI

/// The trackpad mirror: to scale, zone states by shape, joined labels, live touches (BRIEF bones 1–4). Settings window size.
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct PadMirrorView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("PadMirrorView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
