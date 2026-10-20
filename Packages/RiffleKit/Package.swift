// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiffleKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RiffleTheory", targets: ["RiffleTheory"]),
        .library(name: "RiffleDesign", targets: ["RiffleDesign"]),
        .library(name: "RiffleStore", targets: ["RiffleStore"]),
    ],
    targets: [
        // Pure music theory: notes, intervals, scales, chords, tunings, voicings.
        .target(name: "RiffleTheory"),
        // Design tokens, bundled fonts and shared SwiftUI components.
        .target(
            name: "RiffleDesign",
            resources: [.copy("Resources/Fonts")]
        ),
        // SwiftData schema, preferences and streak logic.
        .target(name: "RiffleStore", dependencies: ["RiffleTheory"]),

        .testTarget(name: "RiffleTheoryTests", dependencies: ["RiffleTheory"]),
        .testTarget(name: "RiffleDesignTests", dependencies: ["RiffleDesign"]),
        .testTarget(name: "RiffleStoreTests", dependencies: ["RiffleStore"]),
    ]
)
