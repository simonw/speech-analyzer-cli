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
    targets: [
        .target(name: "SpeechAnalyzerCore"),
        .executableTarget(
            name: "SpeechAnalyzerCLI",
            dependencies: ["SpeechAnalyzerCore"]
        ),
        .testTarget(
            name: "SpeechAnalyzerCoreTests",
            dependencies: ["SpeechAnalyzerCore"]
        )
    ]
)
