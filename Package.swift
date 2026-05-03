// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IndicSwipe",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "IndicSwipe",
            targets: ["IndicSwipe"]),
    ],
    dependencies: [
        // The URL must have '-manager'
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "IndicSwipe",
            dependencies: [
                // This 'package' name must now also include '-manager' to match the URL/Identity
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            path: "IndicSwipe"
        )
    ]
)