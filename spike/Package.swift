// swift-tools-version: 5.9
import PackageDescription

// MothWing engine spike. SpikeKit is dependency-free (compiles + tests on macOS).
// SpikeEngine wires the real on-device Kokoro path via the KokoroSwift package.
let package = Package(
    name: "MothWingSpike",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SpikeKit", targets: ["SpikeKit"]),
        .library(name: "SpikeEngine", targets: ["SpikeEngine"]),
    ],
    dependencies: [
        // Pin to a specific commit/tag before relying on benchmark numbers (see SPIKE.md).
        .package(url: "https://github.com/mlalma/kokoro-ios.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.18.0"),
    ],
    targets: [
        .target(name: "SpikeKit"),
        .target(
            name: "SpikeEngine",
            dependencies: [
                "SpikeKit",
                .product(name: "KokoroSwift", package: "kokoro-ios"),
                .product(name: "MLX", package: "mlx-swift"),
            ]
        ),
        .testTarget(name: "SpikeKitTests", dependencies: ["SpikeKit"]),
    ]
)
