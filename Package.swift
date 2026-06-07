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
        .executable(name: "AdminDocPrivilegedHelper", targets: ["AdminDocPrivilegedHelper"]),
        .library(name: "AdminDocCore", targets: ["AdminDocCore"])
    ],
    targets: [
        .target(
            name: "AdminDocCore",
            path: "Sources/AdminDocCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AdminDoc",
            dependencies: ["AdminDocCore"],
            path: "Sources/AdminDoc"
        ),
        .executableTarget(
            name: "AdminDocPrivilegedHelper",
            dependencies: ["AdminDocCore"],
            path: "Sources/AdminDocPrivilegedHelper"
        ),
        .testTarget(
            name: "AdminDocCoreTests",
            dependencies: ["AdminDocCore"],
            path: "Tests/AdminDocCoreTests"
        )
    ]
)
