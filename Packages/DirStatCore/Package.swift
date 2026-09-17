// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DirStatCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DirStatCore", targets: ["DirStatCore"])
    ],
    targets: [
        .target(name: "DirStatCore"),
        .testTarget(name: "DirStatCoreTests", dependencies: ["DirStatCore"])
    ]
)
