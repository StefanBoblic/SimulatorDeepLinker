// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SimulatorDeepLinkerCLI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "simulator-deep-linker", targets: ["SimulatorDeepLinkerCLI"])
    ],
    targets: [
        .executableTarget(name: "SimulatorDeepLinkerCLI")
    ]
)
