// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiffleKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RiffleTheory", targets: ["RiffleTheory"]),
        .library(name: "RiffleDesign", targets: ["RiffleDesign"]),
        .library(name: "RiffleStore", targets: ["RiffleStore"]),
        .library(name: "RiffleAudio", targets: ["RiffleAudio"]),
        .library(name: "RiffleQuiz", targets: ["RiffleQuiz"]),
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
        // Microphone capture, pitch detection, chord verification, test-clip corpus.
        .target(name: "RiffleAudio", dependencies: ["RiffleTheory"]),
        // Quiz logic: ear-check sessions now; item model, scheduler and daily planner in M5.
        .target(name: "RiffleQuiz", dependencies: ["RiffleTheory"]),

        .testTarget(name: "RiffleTheoryTests", dependencies: ["RiffleTheory"]),
        .testTarget(name: "RiffleDesignTests", dependencies: ["RiffleDesign"]),
        .testTarget(name: "RiffleStoreTests", dependencies: ["RiffleStore"]),
        .testTarget(name: "RiffleAudioTests", dependencies: ["RiffleAudio", "RiffleTheory"]),
        .testTarget(name: "RiffleQuizTests", dependencies: ["RiffleQuiz", "RiffleTheory"]),
    ]
)
