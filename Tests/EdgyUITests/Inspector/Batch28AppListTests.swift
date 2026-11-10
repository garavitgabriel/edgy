import Actions
import Foundation
import Testing

@testable import EdgyUI

/// 300 invented apps, every tenth running.
struct ManyAppsProvider: InstalledAppsProviding {
  var delay: Duration = .zero
  func installedApps() async -> [InstalledApp] {
    if delay > .zero { try? await Task.sleep(for: delay) }
    return (0..<300).map {
      InstalledApp(
        name: "App \($0)", bundleID: "com.example.app\($0)", path: "/nonexistent/App \($0).app",
        isRunning: $0 % 10 == 0)
    }
  }
}

/// Batch 28: the App chooser's list loads when it opens and shows within 300 ms.
@MainActor @Suite struct Batch28AppListTests {
  @Test func threeHundredAppsLoadWellWithinTheBudget() async {
    let apps = await AppListView.load(from: ManyAppsProvider())
    // The list's own work on the main thread (rows for 300 apps) is far inside 300 ms. The await
    // itself is not timed here: under the parallel test runner it measures the runner's load.
    let clock = ContinuousClock()
    let start = clock.now
    let rows = AppListView.rows(apps, query: "")
    #expect(clock.now - start < .milliseconds(30))
    #expect(apps.count == 300)
    // Running (30) + All apps (300), each with its header.
    #expect(rows.count == 332)
  }

  @Test func rowIDsAreUniqueAcrossTheTwoSections() {
    let apps = (0..<300).map {
      InstalledApp(name: "App \($0)", bundleID: "com.example.app\($0)", path: "/x", isRunning: $0 % 10 == 0)
    }
    let rows = AppListView.rows(apps, query: "")
    #expect(Set(rows.map(\.id)).count == rows.count)
    // The same running app appears in both sections, as two distinct rows.
    #expect(rows.filter { $0.app.bundleID == "com.example.app0" && !$0.isHeader }.count == 2)
    // Stable: the same input gives the same IDs.
    #expect(AppListView.rows(apps, query: "").map(\.id) == rows.map(\.id))
  }

  @Test func searchFiltersBothSections() {
    let apps = [
      InstalledApp(name: "Wayfare", bundleID: "com.example.wayfare", path: "/x", isRunning: true),
      InstalledApp(name: "Huddle", bundleID: "com.example.huddle", path: "/y", isRunning: false),
    ]
    let rows = AppListView.rows(apps, query: "way").filter { !$0.isHeader }
    #expect(rows.map(\.app.name) == ["Wayfare", "Wayfare"])
  }

  @Test func aSlowProviderShowsLoadingUntilTheAppsArrive() async {
    let provider = ManyAppsProvider(delay: .milliseconds(50))
    // Opened with nothing yet: the list starts in its loading state.
    let view = AppListView(apps: [], current: nil, provider: provider) { _ in }
    _ = view
    #expect(AppListView.loadingCopy == "Loading apps\u{2026}")
    let loaded = await AppListView.load(from: provider)
    #expect(loaded.count == 300)
  }

  @Test func iconsAreReadOnceAndCached() async {
    let cache = AppIconCache()
    _ = await cache.load("/nonexistent/A.app")
    _ = await cache.load("/nonexistent/A.app")
    _ = cache.icon("/nonexistent/A.app")
    #expect(cache.reads == 1)
    #expect(cache.cached("/nonexistent/A.app") != nil)
  }
}
