import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 34: "Add another key", the key-sequence button people can find (owner ruling 2026-11-10),
/// and its hint line. The recorder is the fake from `InspectorFixtures`; nothing here touches the
/// real keyboard.
@MainActor
@Suite(.serialized)
struct Batch34RecorderTests {
  static let folder = "batch-34"

  // MARK: Rendered views

  /// A row laid out at the inspector's parameter width, with where the recorder's parts landed.
  @MainActor
  final class Laid {
    final class Box { var frames: [RecorderPartBounds.Part: CGRect] = [:] }
    let frames: [RecorderPartBounds.Part: CGRect]
    let height: CGFloat

    init(_ view: some View, width: CGFloat = 340) {
      let box = Box()
      let framed = view.frame(width: width, alignment: .leading)
        .overlayPreferenceValue(RecorderPartBounds.self) { anchors in
          GeometryReader { proxy in
            let _ = { box.frames = anchors.mapValues { proxy[$0] } }()
            Color.clear
          }
        }
      let host = NSHostingView(rootView: framed)
      host.frame = NSRect(origin: .zero, size: NSSize(width: width, height: max(host.fittingSize.height, 1)))
      let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentView = host
      host.layoutSubtreeIfNeeded()
      host.displayIfNeeded()
      frames = box.frames
      height = host.fittingSize.height
    }

    var shows: Set<RecorderPartBounds.Part> { Set(frames.keys) }
  }

  private func row(
    _ stored: String?, hold: Bool = false, recording: Bool = false
  ) -> some View {
    let fake = FakeRecorder()
    let controller = KeyRecorderController(recorder: fake, isHold: hold, now: { Date() }, commitValue: { _, _ in })
    if recording { controller.start(after: stored) }
    return LabeledParameter(label: "Keys", labelWidth: 80) {
      KeyRecorderField(
        stored: stored, isHold: hold, allowsSequence: true, recorder: fake, controller: controller
      ) { _ in }
    }
  }

  // MARK: Item 1: the button

  @Test func labelIsAddAnotherKeyWithTheSameTooltip() {
    #expect(KeyRecorderField.thenLabel == "Add another key")
    #expect(KeyRecorderField.thenTooltip == "Send another shortcut after this one")
  }

  @Test func buttonShowsByTheSameRules() {
    // 1–3 steps, idle: shows.
    for keys in ["ctrl+b", "ctrl+b n", "ctrl+b n cmd+k"] {
      #expect(KeyRecorderController.showsThen(stored: keys, allowsSequence: true, isRecording: false), "\(keys)")
      #expect(Laid(row(keys)).shows.contains(.button), "\(keys)")
    }
    // Empty, 4 steps, recording, Hold Keys: hidden (and absent from the accessibility tree).
    #expect(!KeyRecorderController.showsThen(stored: nil, allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderController.showsThen(stored: "ctrl+b n cmd+k x", allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderController.showsThen(stored: "ctrl+b", allowsSequence: true, isRecording: true))
    #expect(!KeyRecorderController.showsThen(stored: "fn", allowsSequence: false, isRecording: false))
    for view in [row(nil), row("ctrl+b n cmd+k x"), row("ctrl+b", recording: true), row("fn", hold: true)] {
      #expect(!Laid(view).shows.contains(.button))
    }
  }

  @Test func buttonIsTheBorderedInkButton() {
    // It reads at least as wide as its label plus a bezel; the quiet text button had none.
    let button = NSHostingView(rootView: AddAnotherKeyButton {}).fittingSize
    let quiet = NSHostingView(
      rootView: QuietTextButton(title: KeyRecorderField.thenLabel, tooltip: "") {}
    ).fittingSize
    #expect(button.width > quiet.width + 8, "bordered \(button.width), quiet \(quiet.width)")
  }

  // MARK: Item 3: the field keeps its x

  @Test func fieldXIsIdenticalWithTheButtonShowingAndHidden() throws {
    let showing = Laid(row("ctrl+b"))
    let field = try #require(showing.frames[.field])
    let others = [
      row("ctrl+b n"), row("ctrl+b n cmd+k"), row("ctrl+b n cmd+k x"), row("ctrl+b", recording: true), row(nil),
    ]
    for view in others {
      let x = try #require(Laid(view).frames[.field]).minX
      #expect(abs(x - field.minX) <= 0.5, "\(x) vs \(field.minX)")
    }
    // The button sits on its own line under the field, left-aligned with it, above the hint.
    let button = try #require(showing.frames[.button])
    let hint = try #require(showing.frames[.hint])
    #expect(abs(button.minX - field.minX) <= 0.5, "button \(button.minX), field \(field.minX)")
    #expect(button.minY >= field.maxY && hint.minY >= button.maxY)
    // The hint reads in full on one line, inside the row.
    let hintIdeal = NSHostingView(
      rootView: Text(KeyRecorderField.sequenceHint).font(Tokens.font(Tokens.typeBody))
    ).fittingSize.width
    #expect(hint.width >= hintIdeal - 0.5 && hint.maxX <= 340.5, "hint \(hint)")
  }

  // MARK: Item 2: the hint line

  @Test func hintShowsWithTheButtonAndWithFourSteps() {
    #expect(KeyRecorderField.sequenceHint == "Sends these one after another.")
    for keys in ["ctrl+b", "ctrl+b n", "ctrl+b n cmd+k", "ctrl+b n cmd+k x"] {
      #expect(KeyRecorderField.showsSequenceHint(stored: keys, allowsSequence: true, isRecording: false), "\(keys)")
      #expect(Laid(row(keys)).shows.contains(.hint), "\(keys)")
    }
  }

  @Test func hintNeverWhileRecordingNorOnHoldKeysNorEmpty() {
    for keys in ["ctrl+b", "ctrl+b n cmd+k"] {
      #expect(!KeyRecorderField.showsSequenceHint(stored: keys, allowsSequence: true, isRecording: true))
    }
    #expect(!KeyRecorderField.showsSequenceHint(stored: nil, allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderField.showsSequenceHint(stored: "fn", allowsSequence: false, isRecording: false))
    #expect(!KeyRecorderField.showsSequenceHint(stored: "ctrl+b n", allowsSequence: false, isRecording: false))
    let recording = Laid(row("ctrl+b", recording: true))
    #expect(!recording.shows.contains(.hint))
    #expect(KeyRecorderField.showsUseEscape(allowsSequence: true, isRecording: true), "Use Escape owns the line")
    for view in [row("fn", hold: true), row("fn+space", hold: true), row(nil)] {
      let laid = Laid(view)
      #expect(!laid.shows.contains(.hint) && !laid.shows.contains(.button))
      #expect(laid.shows.contains(.field), "the field itself reports, so absence above is real")
    }
    // Heights agree: a hold field is one line, like an empty sequence field.
    #expect(abs(Laid(row("fn", hold: true)).height - Laid(row(nil)).height) <= 0.5)
    #expect(Laid(row("ctrl+b")).height > Laid(row("ctrl+b n cmd+k x")).height)
    #expect(Laid(row("ctrl+b n cmd+k x")).height > Laid(row(nil)).height)
  }

  // MARK: Shots

  private func inspector(_ binding: EdgyCore.Binding, _ name: String) throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings = [binding]
    let model = InspectorFixtures.model(config: config, recorder: FakeRecorder())
    model.selectedZone = .edge(.left)
    model.inspectorDrafts.open = InspectorDrafts.Key(
      profile: model.selectedProfile, binding: binding.key)
    let view = InspectorView(model: model).frame(width: 360, height: 420, alignment: .top)
      .background(Tokens.padTop.opacity(0.35)).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  private func shortcut(_ keys: String) -> EdgyCore.Binding {
    EdgyCore.Binding(zone: .edge(.left), gesture: .tap, action: "keyboard.shortcut", parameters: ["keys": keys])
  }

  @Test func recorderShots() throws {
    try inspector(shortcut("ctrl+b"), "recorder-one-step-add-another")
    try inspector(shortcut("ctrl+b n"), "recorder-two-steps")
    try inspector(shortcut("ctrl+b n cmd+k x"), "recorder-four-steps")
    try inspector(
      EdgyCore.Binding(
        zone: .edge(.left), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn+space"]),
      "recorder-hold-keys")
  }

  @Test func recordingUseEscapeShot() throws {
    let view = row("ctrl+b", recording: true)
      .padding(16).frame(width: 340, alignment: .leading).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: "recorder-recording-use-escape").count == 2)
  }
}
