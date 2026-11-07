import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 22 phase A shots: the action icon sheet (16 pt, and at 2× its size) and the split glyphs.
@MainActor @Suite(.serialized) struct IconSnapshotTests {
  static let folder = "batch-22"

  @Test func iconSheet() throws {
    let model = PreviewFixtures.model()
    let groups = model.editor.catalogByCategory
    let sheet = VStack(alignment: .leading, spacing: 10) {
      ForEach(groups, id: \.category) { group in
        VStack(alignment: .leading, spacing: 4) {
          Text(String(describing: group.category).capitalized)
            .font(Tokens.font(Tokens.typeSmall, semibold: true)).foregroundStyle(Tokens.ink2)
          ForEach(group.actions, id: \.id) { action in
            HStack(spacing: 0) {
              ActionIcon(id: action.id).frame(width: 24, alignment: .leading)
              ActionIcon(id: action.id, size: 32).frame(width: 44, alignment: .leading)
              Text(action.displayName).font(Tokens.font(Tokens.typeBody))
              Spacer(minLength: 8)
              Text(action.id.rawValue).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
            }
            .foregroundStyle(Tokens.ink)
          }
        }
      }
      HStack(spacing: 0) {
        ActionIcon(id: .doNothing).frame(width: 24, alignment: .leading)
        ActionIcon(id: .doNothing, size: 32).frame(width: 44, alignment: .leading)
        Text("Do nothing here").font(Tokens.font(Tokens.typeBody))
      }
      .foregroundStyle(Tokens.ink)
      HStack(spacing: 0) {
        AdvancedIcon().frame(width: 24, alignment: .leading)
        AdvancedIcon(size: 32).frame(width: 44, alignment: .leading)
        Text("Advanced…").font(Tokens.font(Tokens.typeBody))
      }
      .foregroundStyle(Tokens.ink)
    }
    .padding(16)
    .frame(width: 420)
    .background(Tokens.windowTint)
    try Snapshot.write(sheet, folder: Self.folder, name: "icon-sheet")
  }

  @Test func splitGlyphs() throws {
    let sheet = VStack(alignment: .leading, spacing: 16) {
      ForEach([Zone.Edge.top, .left], id: \.self) { edge in
        VStack(alignment: .leading, spacing: 8) {
          Text(edge == .top ? "Top and bottom edges" : "Left and right edges")
            .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
          ForEach([false, true], id: \.self) { selected in
            HStack(spacing: 12) {
              ForEach(1...4, id: \.self) { parts in
                EdgySplitGlyph(edge: edge, parts: parts, selected: selected)
              }
            }
          }
        }
      }
    }
    .padding(16)
    .background(Tokens.windowTint)
    try Snapshot.write(sheet, folder: Self.folder, name: "split-glyphs")
  }
}
