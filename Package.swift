// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClawNest",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClawNest", targets: ["ClawNest"])
    ],
    targets: [
        .executableTarget(
            name: "ClawNest",
            path: "Sources/ClawNest"
        ),
        .testTarget(
            name: "ClawNestTests",
            dependencies: ["ClawNest"],
            path: "Tests/ClawNestTests"
        )
    ],
    swiftLanguageModes: [
        .v6
    ]
)
