// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BaseballIOSLayers",
    platforms: [
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
        )
    ]
)
