// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AdminDoc",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AdminDoc", targets: ["AdminDoc"]),
        .library(name: "AdminDocCore", targets: ["AdminDocCore"])
    ],
    targets: [
        .target(
            name: "AdminDocCore",
            path: "Sources/AdminDocCore"
        ),
        .executableTarget(
            name: "AdminDoc",
            dependencies: ["AdminDocCore"],
            path: "Sources/AdminDoc"
        ),
        .testTarget(
            name: "AdminDocCoreTests",
            dependencies: ["AdminDocCore"],
            path: "Tests/AdminDocCoreTests"
        )
    ]
)
