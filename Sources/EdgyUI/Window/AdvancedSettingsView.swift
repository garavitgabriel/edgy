import EdgyCore
import EdgyRuntime
import SwiftUI

/// The Advanced… sheet, built plain under the tokens (BRIEF § Not yet designed, item 4): gesture
/// tuning with units, then haptic moments and strengths. Every field writes through the editor,
/// which clamps to `GestureSettingsLimits` / `AppSettings.hapticStrengthRange`. A slider drag is
/// one undo step.
public struct AdvancedSettingsView: View {
  @Bindable var model: SettingsModel
  private let done: () -> Void

  static let width: CGFloat = 520
  static let labelWidth: CGFloat = 170
  static let valueWidth: CGFloat = 64

  public init(model: SettingsModel, done: @escaping () -> Void = {}) {
    self.model = model
    self.done = done
  }

  public var body: some View {
    let _ = model.revision
    let app = model.editor.config.app
    VStack(alignment: .leading, spacing: 14) {
      Text("Gestures").font(Tokens.font(Tokens.typeBody, semibold: true))
      ForEach(GestureField.allCases, id: \.self) { field in gestureRow(field) }
      row("Fingers for a slide") {
        Picker(
          "Fingers for a slide",
          selection: Binding(get: { model.editor.config.gestures.fingers }, set: { model.setFingers($0) })
        ) {
          ForEach(Array(GestureSettingsLimits.fingers), id: \.self) { Text("\($0)").tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        Spacer()
      }

      Tokens.line.opacity(0.3).frame(height: 1).padding(.vertical, 4)

      Text("Haptics").font(Tokens.font(Tokens.typeBody, semibold: true))
      VStack(alignment: .leading, spacing: 6) {
        ForEach(HapticEvent.allCases, id: \.self) { event in
          Toggle(
            event.label,
            isOn: Binding(get: { app.hapticEvents.contains(event) }, set: { model.setHapticEvent(event, on: $0) })
          )
          .toggleStyle(.checkbox)
        }
      }
      .disabled(!app.haptics)
      strengthRow("Tick strength", key: "hapticTickStrength", value: app.hapticTickStrength, set: model.setTickStrength)
      strengthRow(
        "Click strength", key: "hapticClickStrength", value: app.hapticClickStrength, set: model.setClickStrength)
      if !app.haptics {
        Text("Haptics are off in the window footer.").foregroundStyle(Tokens.ink2)
      }

      HStack {
        Spacer()
        Button("Done", action: done).buttonStyle(InkButtonStyle()).keyboardShortcut(.defaultAction)
      }
      .padding(.top, 6)
    }
    .font(Tokens.font(Tokens.typeBody))
    .foregroundStyle(Tokens.ink)
    .tint(Tokens.ink)
    .padding(24)
    .frame(width: Self.width)
    .background(WindowMaterial())
  }

  private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 12) {
      Text(label).foregroundStyle(Tokens.ink2).frame(width: Self.labelWidth, alignment: .leading)
      content()
    }
  }

  private func gestureRow(_ field: GestureField) -> some View {
    let value = model.gestureValue(field)
    let shown = min(
      max(value.isFinite ? value : field.range.lowerBound, field.range.lowerBound), field.range.upperBound)
    return VStack(alignment: .leading, spacing: 4) {
      row(field.label) {
        Slider(
          value: Binding(get: { shown }, set: { model.setGesture(field, to: field.snap($0)) }), in: field.range,
          onEditingChanged: { model.continuousEdit(field.rawValue, began: $0) }
        )
        .labelsHidden()
        // A value at its default reads `ink2`, a changed one `ink` (batch-16 design answer 2).
        Text(field.format(shown)).frame(width: Self.valueWidth, alignment: .trailing)
          .foregroundStyle(value == GestureSettings.defaults[keyPath: field.keyPath] ? Tokens.ink2 : Tokens.ink)
      }
      if let note = model.outOfRangeNote(field) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Image(systemName: "exclamationmark.triangle")
          Text(note)
        }
        .foregroundStyle(Tokens.ink2)
        .padding(.leading, Self.labelWidth + 12)
      }
    }
  }

  static func defaultStrength(_ key: String) -> Int {
    key == "hapticTickStrength" ? AppSettings.defaults.hapticTickStrength : AppSettings.defaults.hapticClickStrength
  }

  private func strengthRow(_ label: String, key: String, value: Int, set: @escaping (Int) -> Void) -> some View {
    let range = AppSettings.hapticStrengthRange
    return row(label) {
      Slider(
        value: Binding(get: { Double(value) }, set: { set(Int($0.rounded())) }),
        in: Double(range.lowerBound)...Double(range.upperBound), step: 1,
        onEditingChanged: { model.continuousEdit(key, began: $0) }
      )
      .labelsHidden()
      Text("\(value) of \(range.upperBound)").frame(width: Self.valueWidth, alignment: .trailing)
        .foregroundStyle(value == Self.defaultStrength(key) ? Tokens.ink2 : Tokens.ink)
    }
    .disabled(!model.editor.config.app.haptics)
  }
}
