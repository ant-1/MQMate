import SwiftUI

/// MQMate - macOS IBM MQ Queue Manager Inspector
/// A lightweight companion app for inspecting IBM MQ queue managers
@main
struct MQMateApp: App {

    // MARK: - App State

    /// Shared connection manager instance for the entire application
    @State private var connectionManager = ConnectionManager()

    /// App delegate for handling application lifecycle events
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Body

    var body: some Scene {
        // Main window group
        WindowGroup {
            ContentView(connectionManager: connectionManager)
                .onAppear {
                    // Share connection manager with app delegate for cleanup
                    appDelegate.connectionManager = connectionManager
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 700)
        .defaultPosition(.center)
        .commands {
            // Custom application commands
            CommandGroup(replacing: .newItem) {
                Button("New Connection") {
                    NotificationCenter.default.post(
                        name: .newConnectionRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Refresh Queues") {
                    NotificationCenter.default.post(
                        name: .refreshQueuesRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!connectionManager.hasActiveConnections)
            }

            // Connection commands
            CommandMenu("Connection") {
                Button("Connect") {
                    if let connectionId = connectionManager.selectedConnectionId {
                        Task {
                            try? await connectionManager.connect(id: connectionId)
                        }
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(connectionManager.selectedConnectionId == nil ||
                         connectionManager.isConnected(id: connectionManager.selectedConnectionId ?? UUID()))

                Button("Disconnect") {
                    if let connectionId = connectionManager.selectedConnectionId {
                        connectionManager.disconnect(id: connectionId)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(connectionManager.selectedConnectionId == nil ||
                         !connectionManager.isConnected(id: connectionManager.selectedConnectionId ?? UUID()))

                Divider()

                Button("Disconnect All") {
                    connectionManager.disconnectAll()
                }
                .disabled(!connectionManager.hasActiveConnections)
            }
        }

        // Settings window (Cmd+,)
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user requests to create a new connection (Cmd+N)
    static let newConnectionRequested = Notification.Name("newConnectionRequested")

    /// Posted when user requests to refresh queues (Cmd+R)
    static let refreshQueuesRequested = Notification.Name("refreshQueuesRequested")
}

// MARK: - App Delegate

/// App delegate for handling application lifecycle events
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Reference to the connection manager for cleanup
    var connectionManager: ConnectionManager?

    /// Called when the application is about to terminate
    func applicationWillTerminate(_ notification: Notification) {
        // Disconnect all connections before quitting
        connectionManager?.disconnectAll()
    }

    /// Called when the application finishes launching
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Additional setup can be added here if needed
    }
}

// MARK: - Settings View

/// Application settings/preferences view
struct SettingsView: View {

    // MARK: - State

    /// Currently selected settings tab
    @State private var selectedTab: SettingsTab = .general

    // MARK: - Settings Tab

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case connections = "Connections"
        case appearance = "Appearance"

        var systemImage: String {
            switch self {
            case .general: return "gear"
            case .connections: return "server.rack"
            case .appearance: return "paintbrush"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.systemImage)
                }
                .tag(SettingsTab.general)

            ConnectionSettingsTab()
                .tabItem {
                    Label(SettingsTab.connections.rawValue, systemImage: SettingsTab.connections.systemImage)
                }
                .tag(SettingsTab.connections)

            AppearanceSettingsTab()
                .tabItem {
                    Label(SettingsTab.appearance.rawValue, systemImage: SettingsTab.appearance.systemImage)
                }
                .tag(SettingsTab.appearance)
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings Tab

/// General application settings
struct GeneralSettingsTab: View {

    // MARK: - Settings

    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch: Bool = false
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalSeconds: Int = 30
    @AppStorage("confirmDestructiveActions") private var confirmDestructiveActions: Bool = true

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Toggle("Auto-connect to last used connection on launch", isOn: $autoConnectOnLaunch)

                Toggle("Confirm destructive actions", isOn: $confirmDestructiveActions)
                    .help("Show confirmation dialogs before deleting connections or clearing queues")
            }

            Section("Queue Refresh") {
                Picker("Auto-refresh interval:", selection: $refreshIntervalSeconds) {
                    Text("Never").tag(0)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Connection Settings Tab

/// Connection-related settings
struct ConnectionSettingsTab: View {

    // MARK: - Settings

    @AppStorage("connectionTimeoutSeconds") private var connectionTimeoutSeconds: Int = 30
    @AppStorage("showSystemQueues") private var showSystemQueues: Bool = false
    @AppStorage("defaultChannel") private var defaultChannel: String = "SYSTEM.DEF.SVRCONN"
    @AppStorage("defaultPort") private var defaultPort: Int = 1414

    // MARK: - Body

    var body: some View {
        Form {
            Section("Defaults") {
                TextField("Default channel:", text: $defaultChannel)
                    .textFieldStyle(.roundedBorder)

                Stepper("Default port: \(defaultPort)", value: $defaultPort, in: 1...65535)
            }

            Section("Connection") {
                Picker("Connection timeout:", selection: $connectionTimeoutSeconds) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                }
                .pickerStyle(.menu)
            }

            Section("Queue Display") {
                Toggle("Show system queues by default", isOn: $showSystemQueues)
                    .help("Show queues starting with SYSTEM.* in the queue list")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings Tab

/// Appearance-related settings
struct AppearanceSettingsTab: View {

    // MARK: - Settings

    @AppStorage("sidebarIconSize") private var sidebarIconSize: Int = 16
    @AppStorage("showQueueDepthBars") private var showQueueDepthBars: Bool = true
    @AppStorage("truncateMessagePreview") private var truncateMessagePreview: Int = 100

    // MARK: - Body

    var body: some View {
        Form {
            Section("Queue List") {
                Toggle("Show queue depth capacity bars", isOn: $showQueueDepthBars)
                    .help("Display visual capacity indicators in the queue list")
            }

            Section("Message Browser") {
                Stepper("Message preview length: \(truncateMessagePreview) characters",
                       value: $truncateMessagePreview,
                       in: 50...500,
                       step: 50)
                    .help("Maximum characters to show in message payload preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Previews

#Preview("Settings - General") {
    GeneralSettingsTab()
        .frame(width: 450, height: 300)
}

#Preview("Settings - Connections") {
    ConnectionSettingsTab()
        .frame(width: 450, height: 300)
}

#Preview("Settings - Appearance") {
    AppearanceSettingsTab()
        .frame(width: 450, height: 300)
}
