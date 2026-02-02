import SwiftUI

// MARK: - ConnectionsView

/// Sidebar view displaying the list of queue manager connections
/// Shows connection status indicators and allows selection for navigation
struct ConnectionsView: View {

    // MARK: - Properties

    /// The connection manager providing connection data and operations
    @Bindable var connectionManager: ConnectionManager

    /// Binding to the selected connection ID
    @Binding var selection: UUID?

    /// Show add connection sheet
    @State private var showAddConnection = false

    /// Show edit connection sheet
    @State private var showEditConnection = false

    /// Connection to edit
    @State private var connectionToEdit: ConnectionConfig?

    /// Connection to delete (for confirmation dialog)
    @State private var connectionToDelete: ConnectionConfig?

    /// Show delete confirmation dialog
    @State private var showDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        List(selection: $selection) {
            ForEach(connectionManager.savedConnections) { config in
                ConnectionRowView(
                    config: config,
                    connectionState: connectionManager.connectionState(for: config.id),
                    isConnecting: connectionManager.connectionState(for: config.id) == .connecting
                )
                .tag(config.id)
                .contextMenu {
                    connectionContextMenu(for: config)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Connections")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                addConnectionButton
            }
        }
        .sheet(isPresented: $showAddConnection) {
            addConnectionPlaceholder
        }
        .sheet(item: $connectionToEdit) { config in
            editConnectionPlaceholder(config: config)
        }
        .confirmationDialog(
            "Delete Connection?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: connectionToDelete
        ) { config in
            Button("Delete", role: .destructive) {
                connectionManager.deleteConnection(id: config.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { config in
            Text("Are you sure you want to delete \"\(config.name)\"? This will remove the saved connection and its stored credentials.")
        }
        .overlay {
            if connectionManager.savedConnections.isEmpty {
                emptyStateView
            }
        }
    }

    // MARK: - Subviews

    /// Add connection button
    private var addConnectionButton: some View {
        Button {
            showAddConnection = true
        } label: {
            Image(systemName: "plus")
        }
        .help("Add Connection (⌘N)")
        .keyboardShortcut("n", modifiers: .command)
    }

    /// Empty state when no connections exist
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Connections", systemImage: "server.rack")
        } description: {
            Text("Add a queue manager connection to get started.")
        } actions: {
            Button {
                showAddConnection = true
            } label: {
                Text("Add Connection")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Placeholder view for add connection sheet (to be replaced by ConnectionFormView)
    private var addConnectionPlaceholder: some View {
        VStack(spacing: 20) {
            Text("Add Connection")
                .font(.headline)
            Text("ConnectionFormView will be implemented in subtask-5-2")
                .foregroundStyle(.secondary)
            Button("Close") {
                showAddConnection = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }

    /// Placeholder view for edit connection sheet
    private func editConnectionPlaceholder(config: ConnectionConfig) -> some View {
        VStack(spacing: 20) {
            Text("Edit Connection: \(config.name)")
                .font(.headline)
            Text("ConnectionFormView will be implemented in subtask-5-2")
                .foregroundStyle(.secondary)
            Button("Close") {
                connectionToEdit = nil
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }

    /// Context menu for connection row
    @ViewBuilder
    private func connectionContextMenu(for config: ConnectionConfig) -> some View {
        let state = connectionManager.connectionState(for: config.id)

        if state == .connected {
            Button {
                connectionManager.disconnect(id: config.id)
            } label: {
                Label("Disconnect", systemImage: "bolt.slash")
            }

            Divider()

            Button {
                Task {
                    try? await connectionManager.refreshQueues(for: config.id)
                }
            } label: {
                Label("Refresh Queues", systemImage: "arrow.clockwise")
            }
        } else if state.canConnect {
            Button {
                Task {
                    try? await connectionManager.connect(id: config.id)
                }
            } label: {
                Label("Connect", systemImage: "bolt")
            }
        }

        Divider()

        Button {
            connectionToEdit = config
        } label: {
            Label("Edit Connection...", systemImage: "pencil")
        }

        Button {
            duplicateConnection(config)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            connectionToDelete = config
            showDeleteConfirmation = true
        } label: {
            Label("Delete...", systemImage: "trash")
        }
    }

    // MARK: - Actions

    /// Duplicate a connection
    private func duplicateConnection(_ config: ConnectionConfig) {
        do {
            let newConfig = try connectionManager.duplicateConnection(id: config.id)
            // Select the new connection
            selection = newConfig.id
        } catch {
            // Error handled by connection manager
        }
    }
}

// MARK: - ConnectionRowView

/// Row view for displaying a single connection in the sidebar list
struct ConnectionRowView: View {

    /// Connection configuration
    let config: ConnectionConfig

    /// Current connection state
    let connectionState: QueueManager.ConnectionState

    /// Whether the connection is currently connecting
    let isConnecting: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            statusIndicator

            // Connection details
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(config.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Queue manager name badge
            if connectionState == .connected {
                Text(config.queueManager)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// Status indicator icon
    @ViewBuilder
    private var statusIndicator: some View {
        if isConnecting {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: connectionState.systemImageName)
                .foregroundStyle(statusColor)
                .imageScale(.medium)
                .frame(width: 16, height: 16)
        }
    }

    /// Color for the status indicator
    private var statusColor: Color {
        switch connectionState {
        case .disconnected:
            return .secondary
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .disconnecting:
            return .orange
        case .error:
            return .red
        }
    }

    /// Accessibility label for the row
    private var accessibilityLabel: String {
        "\(config.name), \(connectionState.displayName)"
    }

    /// Accessibility hint for the row
    private var accessibilityHint: String {
        switch connectionState {
        case .connected:
            return "Double-click to view queues. Right-click for options."
        case .disconnected, .error:
            return "Double-click to connect. Right-click for options."
        case .connecting:
            return "Connecting to queue manager."
        case .disconnecting:
            return "Disconnecting from queue manager."
        }
    }
}

// MARK: - Convenience Extension for ConnectionState

private extension QueueManager.ConnectionState {
    /// Check if this state allows connecting
    var canConnect: Bool {
        self == .disconnected || self == .error
    }
}

// MARK: - Previews

#Preview("With Connections") {
    @Previewable @State var selection: UUID? = nil

    NavigationSplitView {
        ConnectionsView(
            connectionManager: ConnectionManager.preview,
            selection: $selection
        )
    } detail: {
        Text("Select a connection")
    }
    .frame(width: 800, height: 600)
}

#Preview("Empty State") {
    @Previewable @State var selection: UUID? = nil

    let emptyManager = ConnectionManager(
        mqService: MockMQService(),
        keychainService: MockKeychainService()
    )

    NavigationSplitView {
        ConnectionsView(
            connectionManager: emptyManager,
            selection: $selection
        )
    } detail: {
        Text("Select a connection")
    }
    .frame(width: 800, height: 600)
}

#Preview("Connection Row - Connected") {
    List {
        ConnectionRowView(
            config: ConnectionConfig.sample,
            connectionState: .connected,
            isConnecting: false
        )
    }
    .listStyle(.sidebar)
    .frame(width: 280, height: 100)
}

#Preview("Connection Row - Disconnected") {
    List {
        ConnectionRowView(
            config: ConnectionConfig.sample,
            connectionState: .disconnected,
            isConnecting: false
        )
    }
    .listStyle(.sidebar)
    .frame(width: 280, height: 100)
}

#Preview("Connection Row - Connecting") {
    List {
        ConnectionRowView(
            config: ConnectionConfig.sample,
            connectionState: .connecting,
            isConnecting: true
        )
    }
    .listStyle(.sidebar)
    .frame(width: 280, height: 100)
}

#Preview("Connection Row - Error") {
    List {
        ConnectionRowView(
            config: ConnectionConfig.sample,
            connectionState: .error,
            isConnecting: false
        )
    }
    .listStyle(.sidebar)
    .frame(width: 280, height: 100)
}
