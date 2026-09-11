// swift-tools-version: 5.9
import PackageDescription

// Pure-Swift logic shared by app and widget. No UIKit, so `swift test` runs on the macOS runner.
let package = Package(
    name: "Core",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Core", targets: ["Core"])],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
    ]
)
