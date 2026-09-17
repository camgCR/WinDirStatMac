// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinDirStatMac",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Packages/DirStatCore")
    ],
    targets: [
        .executableTarget(
            name: "WinDirStatMac",
            dependencies: ["DirStatCore"],
            path: "WinDirStatMac"
        )
    ]
)
