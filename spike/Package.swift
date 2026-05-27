// swift-tools-version: 6.0
import PackageDescription

// MothWing engine spike. SpikeKit is dependency-free (compiles + tests on macOS).
// SpikeEngine wires the real on-device Kokoro path via the KokoroSwift package.
//
// kokoro-ios (and its deps) use a Swift 6.2 manifest, so a recent toolchain
// (Xcode 26+/Swift 6.2) is required to resolve and build SpikeEngine + the app.
// SpikeKit alone (`swift test`) has no external deps.
let package = Package(
    name: "MothWingSpike",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SpikeKit", targets: ["SpikeKit"]),
        .library(name: "SpikeEngine", targets: ["SpikeEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mlalma/kokoro-ios.git", exact: "1.0.11"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.2"),
        .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6"),
    ],
    targets: [
        .target(name: "SpikeKit"),
        .target(
            name: "SpikeEngine",
            dependencies: [
                "SpikeKit",
                .product(name: "KokoroSwift", package: "kokoro-ios"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary"),
            ]
        ),
        .testTarget(name: "SpikeKitTests", dependencies: ["SpikeKit"]),
    ]
)
