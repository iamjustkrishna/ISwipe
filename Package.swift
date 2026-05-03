// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IndicSwipe",
    platforms: [
        .iOS(.v15),
        .macOS(.v14) // Add this line to match onnxruntime's requirement
    ],
    products: [
        .library(
            name: "IndicSwipe",
            targets: ["IndicSwipe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "IndicSwipe",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            path: "IndicSwipe"
        )
    ]
)