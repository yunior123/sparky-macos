// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sparky",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Sparky", targets: ["Sparky"])
    ],
    targets: [
        .executableTarget(
            name: "Sparky",
            path: "Sources"
        )
    ]
)
