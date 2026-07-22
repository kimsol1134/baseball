// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BaseballSimulation",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SimulationCore", targets: ["SimulationCore"]),
        .library(name: "SimulationProtocol", targets: ["SimulationProtocol"]),
        .library(name: "SimulationPersistence", targets: ["SimulationPersistence"]),
        .executable(name: "simulation-sidecar", targets: ["SimulationSidecar"]),
        .executable(name: "simulation-cli", targets: ["SimulationCLI"]),
        .executable(name: "save-archive-cli", targets: ["SaveArchiveCLI"])
    ],
    targets: [
        .target(name: "SimulationCore"),
        .target(name: "SimulationPersistence"),
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
        .executableTarget(
            name: "SaveArchiveCLI",
            dependencies: ["SimulationPersistence"]
        ),
        .testTarget(
            name: "SimulationCoreTests",
            dependencies: ["SimulationCore"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "SimulationProtocolTests",
            dependencies: ["SimulationProtocol"]
        ),
        .testTarget(
            name: "SimulationPersistenceTests",
            dependencies: ["SimulationPersistence"]
        )
    ]
)
