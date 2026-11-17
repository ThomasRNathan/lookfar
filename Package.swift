// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LookFar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LookFar", targets: ["LookFar"]),
        .library(name: "LookFarCore", targets: ["LookFarCore"]),
    ],
    targets: [
        // Pure Swift scheduling logic. No AppKit, so it is easy to test.
        .target(name: "LookFarCore"),
        // The menu bar app: SwiftUI + AppKit.
        .executableTarget(name: "LookFar", dependencies: ["LookFarCore"]),
        .testTarget(name: "LookFarCoreTests", dependencies: ["LookFarCore"]),
    ]
)
