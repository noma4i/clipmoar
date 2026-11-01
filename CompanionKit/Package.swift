// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CompanionKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "CompanionKit", targets: ["CompanionKit"])],
    targets: [.target(name: "CompanionKit")]
)
