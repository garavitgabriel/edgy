import EdgyCore
import EdgyRuntime
import SwiftUI

/// The settings window content: profile tabs, mirror, inspector, footer (§ Surfaces, § App profiles, § System states, § Issue states).
///
/// Skeleton (chief). The owning batch replaces the body and may add files in this folder; the
/// type name and initializer stay as they are so other batches can compose it.
public struct SettingsWindowView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    Text("SettingsWindowView").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}
