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
        // ONNX Runtime for iOS
        // Provides ORTEnv, ORTSession, etc. for executing our Swipe and Xlit models.
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package.git", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "IndicSwipe",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package")
            ],
            path: "IndicSwipe"
        )
    ]
)
