import SwiftUI

/// MQMate - macOS IBM MQ Queue Manager Inspector
/// A lightweight companion app for inspecting IBM MQ queue managers
@main
struct MQMateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 600)
    }
}
