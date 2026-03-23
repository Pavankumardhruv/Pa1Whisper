// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Pa1Whisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pa1Whisper",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "OpenWhisper",
            exclude: ["Info.plist", "Pa1Whisper.entitlements"],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
