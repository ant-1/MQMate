import SwiftUI

// MARK: - ContentView

/// Main content view with NavigationSplitView three-column layout
/// Displays: Sidebar (Connections) | Content (Queues) | Detail (Messages)
struct ContentView: View {

    // MARK: - State

    /// The connection manager providing connection data and operations
    @State private var connectionManager: ConnectionManager

    /// The queue view model for the middle column
    @State private var queueViewModel = QueueViewModel()

    /// The message view model for the detail column
    @State private var messageViewModel = MessageViewModel()

    /// Selected connection ID (for sidebar)
    @State private var selectedConnectionId: UUID?

    /// Selected queue ID/name (for content column)
    @State private var selectedQueueId: String?

    /// Selected message ID (for detail column)
    @State private var selectedMessageId: String?

    /// Column visibility state for NavigationSplitView
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Initialization

    init(connectionManager: ConnectionManager? = nil) {
        // Use provided connection manager or create new instance
        _connectionManager = State(initialValue: connectionManager ?? ConnectionManager())
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Connection list
            ConnectionsView(
                connectionManager: connectionManager,
                selection: $selectedConnectionId
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } content: {
            // Content: Queue list for selected connection
            queueListContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 450)
        } detail: {
            // Detail: Message browser for selected queue
            messageBrowserDetail
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedConnectionId) { oldValue, newValue in
            handleConnectionSelectionChange(from: oldValue, to: newValue)
        }
        .onChange(of: selectedQueueId) { oldValue, newValue in
            handleQueueSelectionChange(from: oldValue, to: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshQueuesRequested)) { _ in
            handleRefreshQueuesRequest()
        }
    }

    // MARK: - Command Handlers

    /// Handle refresh queues request from menu command (Cmd+R)
    private func handleRefreshQueuesRequest() {
        guard let connectionId = selectedConnectionId,
              connectionManager.isConnected(id: connectionId) else {
            return
        }

        Task {
            try? await connectionManager.refreshQueues(for: connectionId)
            // Update queue view model with refreshed queues
            let queues = connectionManager.queues(for: connectionId)
            queueViewModel.setQueues(queues)
        }
    }

    // MARK: - Subviews

    /// Queue list content view
    @ViewBuilder
    private var queueListContent: some View {
        if let connectionId = selectedConnectionId,
           connectionManager.isConnected(id: connectionId) {
            QueueListView(
                queueViewModel: queueViewModel,
                selection: $selectedQueueId
            )
        } else if let connectionId = selectedConnectionId {
            // Connection exists but not connected
            connectionPendingView(for: connectionId)
        } else {
            // No connection selected
            selectConnectionPlaceholder
        }
    }

    /// Message browser detail view
    @ViewBuilder
    private var messageBrowserDetail: some View {
        if let queueName = selectedQueueId {
            MessageBrowserView(
                messageViewModel: messageViewModel,
                queueName: queueName,
                selection: $selectedMessageId
            )
        } else {
            // No queue selected
            selectQueuePlaceholder
        }
    }

    /// Placeholder view when no connection is selected
    private var selectConnectionPlaceholder: some View {
        ContentUnavailableView {
            Label("No Connection Selected", systemImage: "server.rack")
        } description: {
            Text("Select a connection from the sidebar to view its queues.")
        }
    }

    /// Placeholder view when no queue is selected
    private var selectQueuePlaceholder: some View {
        ContentUnavailableView {
            Label("No Queue Selected", systemImage: "tray")
        } description: {
            Text("Select a queue to browse its messages.")
        }
    }

    /// View shown when a connection is selected but not yet connected
    @ViewBuilder
    private func connectionPendingView(for connectionId: UUID) -> some View {
        let state = connectionManager.connectionState(for: connectionId)
        let config = connectionManager.savedConnections.first { $0.id == connectionId }

        VStack(spacing: 16) {
            switch state {
            case .disconnected:
                ContentUnavailableView {
                    Label("Not Connected", systemImage: "bolt.slash")
                } description: {
                    if let name = config?.name {
                        Text("\"\(name)\" is not connected.")
                    } else {
                        Text("This connection is not active.")
                    }
                } actions: {
                    Button {
                        Task {
                            try? await connectionManager.connect(id: connectionId)
                        }
                    } label: {
                        Text("Connect")
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .connecting:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Connecting...")
                        .font(.headline)
                    if let name = config?.name {
                        Text("Establishing connection to \"\(name)\"")
                            .foregroundStyle(.secondary)
                    }
                }

            case .disconnecting:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Disconnecting...")
                        .font(.headline)
                }

            case .error:
                ContentUnavailableView {
                    Label("Connection Error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    if let error = connectionManager.lastError {
                        Text(error.localizedDescription)
                    } else {
                        Text("An error occurred while connecting.")
                    }
                } actions: {
                    Button {
                        Task {
                            try? await connectionManager.connect(id: connectionId)
                        }
                    } label: {
                        Text("Retry")
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .connected:
                // This case is handled in queueListContent, but included for completeness
                EmptyView()
            }
        }
    }

    // MARK: - Selection Handlers

    /// Handle connection selection changes
    /// When a new connection is selected, update the queue list and clear queue/message selections
    private func handleConnectionSelectionChange(from oldValue: UUID?, to newValue: UUID?) {
        // Clear downstream selections when connection changes
        selectedQueueId = nil
        selectedMessageId = nil
        messageViewModel.clearMessages()

        guard let newConnectionId = newValue else {
            // No connection selected, clear queues
            queueViewModel.clearQueues()
            return
        }

        // Sync connection manager selection
        connectionManager.selectConnection(id: newConnectionId)

        // Load queues if connection is active
        if connectionManager.isConnected(id: newConnectionId) {
            // Get queues from the queue manager
            let queues = connectionManager.queues(for: newConnectionId)
            queueViewModel.setQueues(queues)
        } else {
            queueViewModel.clearQueues()
        }
    }

    /// Handle queue selection changes
    /// When a new queue is selected, clear message selection and trigger message browsing
    private func handleQueueSelectionChange(from oldValue: String?, to newValue: String?) {
        // Clear message selection when queue changes
        selectedMessageId = nil

        guard let queueName = newValue else {
            // No queue selected, clear messages
            messageViewModel.clearMessages()
            return
        }

        // Browse messages for the selected queue
        Task {
            try? await messageViewModel.browseMessages(queueName: queueName)
        }
    }
}

// MARK: - Preview

#Preview("Full Layout") {
    ContentView(connectionManager: ConnectionManager.preview)
        .frame(width: 1200, height: 700)
}

#Preview("Empty State") {
    ContentView(connectionManager: ConnectionManager(
        mqService: MockMQService(),
        keychainService: MockKeychainService()
    ))
    .frame(width: 1200, height: 700)
}
