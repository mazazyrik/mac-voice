// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacVoice",
    defaultLocalization: "en",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(name: "MacVoice", targets: ["MacVoice"])
    ],
    targets: [
        .executableTarget(
            name: "MacVoice",
            path: "Sources/MacVoice",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "MacVoiceTests",
            dependencies: ["MacVoice"],
            path: "Tests/MacVoiceTests"
        )
    ]
)
