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
        // Updated URL to include '-manager'
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "IndicSwipe",
            dependencies: [
                // The product name is 'onnxruntime', but the package reference 
                // must match the name defined in the remote repository.
                .product(name: "onnxruntime", package: "onnxruntime-swift-package")
            ],
            path: "IndicSwipe"
        )
    ]
)