// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zest",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Zest",
            targets: ["Zest"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Zest",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["Zest"],
            path: "Tests/ZestTests"
        )
    ]
)
