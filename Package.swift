// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipMoar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipMoar",
            path: "ClipMoar",
            exclude: ["Resources"]
        )
    ]
)
