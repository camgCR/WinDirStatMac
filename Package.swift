// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindirStatMac",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/DirStatCore")
    ],
    targets: [
        .executableTarget(
            name: "WindirStatMac",
            dependencies: ["DirStatCore"],
            path: "WindirStatMac"
        )
    ]
)
