// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AdminDoctor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AdminDoctor", targets: ["AdminDoctor"]),
        .executable(name: "AdminDoctorPrivilegedHelper", targets: ["AdminDoctorPrivilegedHelper"]),
        .library(name: "AdminDoctorCore", targets: ["AdminDoctorCore"])
    ],
    targets: [
        .target(
            name: "AdminDoctorCore",
            path: "Sources/AdminDoctorCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AdminDoctor",
            dependencies: ["AdminDoctorCore"],
            path: "Sources/AdminDoctor"
        ),
        .executableTarget(
            name: "AdminDoctorPrivilegedHelper",
            dependencies: ["AdminDoctorCore"],
            path: "Sources/AdminDoctorPrivilegedHelper"
        ),
        .testTarget(
            name: "AdminDoctorCoreTests",
            dependencies: ["AdminDoctorCore"],
            path: "Tests/AdminDoctorCoreTests"
        )
    ]
)
