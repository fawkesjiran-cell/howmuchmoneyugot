// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HowMuch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HowMuch", targets: ["HowMuchApp"])
    ],
    dependencies: [
        .package(path: "Vendor/Vortex")
    ],
    targets: [
        .target(
            name: "HowMuchCore",
            path: "Sources/HowMuchCore"
        ),
        .executableTarget(
            name: "HowMuchApp",
            dependencies: [
                "HowMuchCore",
                .product(name: "Vortex", package: "Vortex")
            ],
            path: "Sources/HowMuchApp"
        ),
        .executableTarget(
            name: "CoreChecks",
            dependencies: ["HowMuchCore"],
            path: "Tests/CoreChecks"
        )
    ]
)
