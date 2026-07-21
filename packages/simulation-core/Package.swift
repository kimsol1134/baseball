// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DiamondSoulSimulation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SimulationCore", targets: ["SimulationCore"]),
        .library(name: "SimulationProtocol", targets: ["SimulationProtocol"]),
        .executable(name: "simulation-sidecar", targets: ["SimulationSidecar"]),
        .executable(name: "simulation-cli", targets: ["SimulationCLI"])
    ],
    targets: [
        .target(name: "SimulationCore"),
        .target(
            name: "SimulationProtocol",
            dependencies: ["SimulationCore"]
        ),
        .executableTarget(
            name: "SimulationSidecar",
            dependencies: ["SimulationProtocol"]
        ),
        .executableTarget(
            name: "SimulationCLI",
            dependencies: ["SimulationCore"]
        ),
        .testTarget(
            name: "SimulationCoreTests",
            dependencies: ["SimulationCore"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "SimulationProtocolTests",
            dependencies: ["SimulationProtocol"]
        )
    ]
)
