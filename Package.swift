// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Edgy",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Edgy", targets: ["EdgyApp"]),
    .executable(name: "edgy-trace", targets: ["EdgyTrace"]),
    .executable(name: "edgy-displays", targets: ["EdgyDisplaysCLI"]),
  ],
  targets: [
    // Shared, chief-owned contracts. Frozen during parallel batches.
    .target(name: "EdgyCore"),
    // Raw touch input (private MultitouchSupport bridge), device hot-plug, trace recorder, PointerGuard.
    .target(name: "TouchKit", dependencies: ["EdgyCore"]),
    // Pure gesture pipeline: zone classifier, misfire defense, recognizers. No system calls.
    .target(name: "Gestures", dependencies: ["EdgyCore"]),
    // Action registry + system outputs (audio, display, media, HUD, haptics, Shortcuts).
    .target(name: "Actions", dependencies: ["EdgyCore", "Displays"]),
    // Display discovery + brightness for built-in, Apple external and third-party (DDC/CI) monitors.
    .target(name: "Displays"),
    // App logic that is testable without a UI: config store, router, pipeline wiring.
    .target(name: "EdgyRuntime", dependencies: ["EdgyCore"]),
    // Trace recorder CLI (owned by the touch batch).
    .executableTarget(name: "EdgyTrace", dependencies: ["EdgyCore", "TouchKit"]),
    // Display probe / brightness smoke CLI (owned by the displays batch).
    .executableTarget(name: "EdgyDisplaysCLI", dependencies: ["Displays"]),
    // Menu-bar app shell: config store, router wiring, bundling.
    .executableTarget(name: "EdgyApp", dependencies: ["EdgyCore", "EdgyRuntime", "TouchKit", "Gestures", "Actions"]),

    .testTarget(name: "EdgyCoreTests", dependencies: ["EdgyCore"]),
    .testTarget(name: "TouchKitTests", dependencies: ["TouchKit"]),
    .testTarget(
      name: "GesturesTests", dependencies: ["Gestures"],
      resources: [.copy("Fixtures")]),
    .testTarget(name: "ActionsTests", dependencies: ["Actions"]),
    .testTarget(name: "DisplaysTests", dependencies: ["Displays"]),
    .testTarget(name: "EdgyRuntimeTests", dependencies: ["EdgyRuntime"]),
    .testTarget(name: "IntegrationTests", dependencies: ["Actions", "EdgyRuntime"]),
  ]
)
