// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LiveSubAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LiveSubAI", targets: ["LiveSubAI"])
    ],
    targets: [
        .executableTarget(
            name: "LiveSubAI",
            path: "LiveSubAI",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security")
            ]
        )
    ]
)
