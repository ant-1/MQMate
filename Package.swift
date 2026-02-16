// swift-tools-version:5.9
// MQMate - macOS IBM MQ Queue Manager Inspector
// Build: swift build
// Run: ./.build/debug/MQMate

import PackageDescription

let package = Package(
    name: "MQMate",
    platforms: [
        .macOS(.v14)  // Required for @Observable macro
    ],
    products: [
        .executable(name: "MQMate", targets: ["MQMate"])
    ],
    targets: [
        // System library target for IBM MQ C Client interop
        // Requires IBM MQ Client installed at /opt/mqm
        // Install: brew tap ibm-messaging/ibmmq && brew install --cask ibm-messaging/ibmmq/ibmmq
        .systemLibrary(
            name: "CMQC",
            path: "Sources/CMQC",
            pkgConfig: nil,
            providers: [
                .brew(["ibm-messaging/ibmmq/ibmmq"])
            ]
        ),
        // Main executable target
        .executableTarget(
            name: "MQMate",
            dependencies: ["CMQC"],
            path: "Sources/MQMate",
            linkerSettings: [
                .unsafeFlags(["-L/opt/mqm/lib64"]),
                .linkedLibrary("mqic_r")
            ]
        ),
        // Test target
        .testTarget(
            name: "MQMateTests",
            dependencies: ["MQMate"],
            path: "Tests/MQMateTests"
        )
    ]
)
