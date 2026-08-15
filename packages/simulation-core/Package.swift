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
        .executable(name: "save-archive-cli", targets: ["SaveArchiveCLI"]),
        .executable(name: "pitch-oracle-fixture-exporter", targets: ["PitchOracleFixtureExporter"]),
        .executable(name: "high-school-phase4-fixture-exporter", targets: ["HighSchoolPhase4FixtureExporter"]),
        .executable(name: "pro-career-fixture-exporter", targets: ["ProCareerFixtureExporter"]),
        .executable(name: "pro-career-fixture-exporter-v2", targets: ["ProCareerFixtureExporterV2"]),
        .executable(name: "pro-career-distribution-runner", targets: ["ProCareerDistributionRunner"])
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
        .executableTarget(
            name: "PitchOracleFixtureExporter",
            dependencies: ["SimulationCore"]
        ),
        .executableTarget(
            name: "HighSchoolPhase4FixtureExporter",
            dependencies: ["SimulationCore"]
        ),
        .executableTarget(
            name: "ProCareerFixtureExporter",
            dependencies: ["SimulationCore"]
        ),
        .executableTarget(
            name: "ProCareerFixtureExporterV2",
            dependencies: ["SimulationCore"]
        ),
        .executableTarget(
            name: "ProCareerDistributionRunner",
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
        ),
        .testTarget(
            name: "SimulationPersistenceTests",
            dependencies: ["SimulationPersistence"]
        )
    ]
)
