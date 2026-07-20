// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "speech-analyzer-cli",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "speech-analyzer", targets: ["SpeechAnalyzerCLI"])
    ],
    dependencies: [
        // SpeakerKit (pyannote) — on-device speaker diarization for --diarize.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "SpeechAnalyzerCore"),
        .executableTarget(
            name: "SpeechAnalyzerCLI",
            dependencies: [
                "SpeechAnalyzerCore",
                .product(name: "SpeakerKit", package: "argmax-oss-swift")
            ]
        ),
        .testTarget(
            name: "SpeechAnalyzerCoreTests",
            dependencies: ["SpeechAnalyzerCore"]
        )
    ]
)
