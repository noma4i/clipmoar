// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipMoar",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "CompanionKit")],
    targets: [
        .executableTarget(
            name: "ClipMoar",
            path: "ClipMoar",
            exclude: [
                "Resources",
            ]
        ),
        .testTarget(
            name: "ClipMoarTests",
            dependencies: ["ClipMoar", "CompanionKit"],
            path: "Tests"
        ),
    ]
)
