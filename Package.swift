// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Theo",
    products: [
        .library(name: "Theo", targets: ["Theo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/providentiaww/Bolt-swift.git", from: "5.0.0"),
        .package(url: "https://github.com/providentiaww/Result.git", from: "5.0.0"),
        .package(url: "https://github.com/providentiaww/LoremSwiftum.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "Theo",
            dependencies: ["Bolt", "Result"]),
        .testTarget(
            name: "TheoTests",
            dependencies: ["Theo", "LoremSwiftum"]),
    ]
)
