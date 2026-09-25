// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "ClariDiff",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ClariDiffCore", targets: ["ClariDiffCore"]),
        .library(name: "ClariDiffUI", targets: ["ClariDiffUI"]),
        .executable(name: "claridiff", targets: ["ClariDiffCLI"]),
        .executable(name: "ClariDiffApp", targets: ["ClariDiffApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", exact: "5.4.0")
    ],
    targets: [
        .target(
            name: "ClariDiffCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .target(
            name: "ClariDiffUI",
            dependencies: ["ClariDiffCore"]
        ),
        .executableTarget(
            name: "ClariDiffCLI",
            dependencies: ["ClariDiffCore"]
        ),
        .executableTarget(
            name: "ClariDiffApp",
            dependencies: ["ClariDiffUI"]
        ),
        .testTarget(
            name: "ClariDiffCoreTests",
            dependencies: ["ClariDiffCore"]
        )
    ]
)
