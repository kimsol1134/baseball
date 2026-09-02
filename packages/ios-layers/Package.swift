// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BaseballIOSLayers",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "BaseballIOSDomain", targets: ["BaseballIOSDomain"]),
        .library(name: "BaseballIOSPersistence", targets: ["BaseballIOSPersistence"])
    ],
    dependencies: [
        .package(path: "../simulation-core")
    ],
    targets: [
        .target(
            name: "BaseballIOSDomain",
            dependencies: [
                .product(name: "SimulationCore", package: "simulation-core")
            ]
        ),
        .target(
            name: "BaseballIOSPersistence",
            dependencies: [
                "BaseballIOSDomain",
                .product(name: "SimulationCore", package: "simulation-core")
            ]
        ),
        .testTarget(
            name: "BaseballIOSPersistenceTests",
            dependencies: [
                "BaseballIOSPersistence",
                "BaseballIOSDomain",
                .product(name: "SimulationCore", package: "simulation-core")
            ]
        )
    ]
)
