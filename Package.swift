// swift-tools-version:5.9
// MQMate - macOS IBM MQ Queue Manager Inspector
// Build: swift build
// Run: ./.build/debug/MQMate

import PackageDescription
import Foundation

// Check if IBM MQ Client is installed
let mqInstalled = FileManager.default.fileExists(atPath: "/opt/mqm/lib64/libmqic_r.dylib")

// Build linker settings based on MQ availability
var linkerSettings: [LinkerSetting] = []
if mqInstalled {
    linkerSettings = [
        .unsafeFlags(["-L/opt/mqm/lib64"]),
        .linkedLibrary("mqic_r")
    ]
}

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
            linkerSettings: linkerSettings
        ),
        // Test target
        .testTarget(
            name: "MQMateTests",
            dependencies: ["MQMate"],
            path: "Tests/MQMateTests"
        )
    ]
)
