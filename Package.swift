// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Recorder",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Recorder", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "RecorderTests", dependencies: ["Recorder"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
