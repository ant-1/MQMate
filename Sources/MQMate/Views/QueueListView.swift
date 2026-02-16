import SwiftUI

// MARK: - QueueListView

/// Content column view displaying the list of queues for a connected queue manager
/// Shows queue names, depths, and status indicators with selection support
struct QueueListView: View {

    // MARK: - Properties

    /// The queue view model providing queue data and operations
    @Bindable var queueViewModel: QueueViewModel

    /// Binding to the selected queue ID (queue name)
    @Binding var selection: String?

    /// Optional queue manager name for audit logging
    var queueManagerName: String?

    /// Show sort picker popover
    @State private var showSortPicker = false

    /// Queue selected for purge operation (for confirmation dialog)
    @State private var queueToPurge: Queue?

    /// Show purge confirmation dialog
    @State private var showPurgeConfirmation = false

    /// Queue selected for delete operation (for confirmation dialog)
    @State private var queueToDelete: Queue?

    /// Show delete confirmation dialog
    @State private var showDeleteConfirmation = false

    /// Operation in progress indicator
    @State private var isOperationInProgress = false

    /// Show create queue sheet
    @State private var showCreateQueueSheet = false

    // MARK: - Body

    var body: some View {
        Group {
            if queueViewModel.isLoading {
                loadingView
            } else if queueViewModel.isEmpty {
                emptyStateView
            } else if queueViewModel.isFilteredEmpty {
                noResultsView
            } else {
                queueListView
            }
        }
        .navigationTitle("Queues")
        .searchable(
            text: $queueViewModel.searchText,
            placement: .toolbar,
            prompt: "Filter queues"
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                newQueueButton
                sortButton
                refreshButton
                filterButton
            }
        }
        .sheet(isPresented: $showCreateQueueSheet) {
            QueueFormView(
                mode: .add,
                onSave: { queueName, queueType in
                    Task {
                        await performCreateQueue(name: queueName, type: queueType)
                    }
                    showCreateQueueSheet = false
                },
                onCancel: {
                    showCreateQueueSheet = false
                }
            )
        }
        .alert(
            "Error Loading Queues",
            isPresented: $queueViewModel.showErrorAlert,
            presenting: queueViewModel.lastError
        ) { _ in
            Button("OK") {
                queueViewModel.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .confirmationDialog(
            "Purge Queue?",
            isPresented: $showPurgeConfirmation,
            titleVisibility: .visible,
            presenting: queueToPurge
        ) { queue in
            purgeConfirmationButtons(for: queue)
        } message: { queue in
            Text("Are you sure you want to purge all \(queue.depth) message\(queue.depth == 1 ? "" : "s") from \"\(queue.name)\"? This action cannot be undone.")
        }
        .confirmationDialog(
            "Delete Queue?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: queueToDelete
        ) { queue in
            deleteConfirmationButtons(for: queue)
        } message: { queue in
            Text("Are you sure you want to delete the queue \"\(queue.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Subviews

    /// Main queue list
    private var queueListView: some View {
        List(selection: $selection) {
            ForEach(queueViewModel.filteredQueues) { queue in
                QueueRowView(queue: queue)
                    .tag(queue.id)
                    .contextMenu {
                        queueContextMenu(for: queue)
                    }
            }
        }
        .listStyle(.inset)
        .refreshable {
            try? await queueViewModel.refresh()
        }
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    /// Loading indicator
    private var loadingView: some View {
        LoadingView("Loading queues...")
    }

    /// Empty state when no queues exist
    private var emptyStateView: some View {
        EmptyStateView.noQueues {
            Task {
                try? await queueViewModel.refresh()
            }
        }
    }

    /// No results when filter matches nothing
    private var noResultsView: some View {
        ContentUnavailableView.search(text: queueViewModel.searchText)
    }

    /// Status bar at bottom showing summary
    private var statusBar: some View {
        HStack {
            Text(queueViewModel.summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let date = queueViewModel.lastRefreshDate {
                Text("Updated \(date, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// New queue button
    private var newQueueButton: some View {
        Button {
            showCreateQueueSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .help("New Queue (⌘N)")
        .keyboardShortcut("n", modifiers: .command)
        .disabled(queueViewModel.isLoading || isOperationInProgress)
    }

    /// Sort order button
    private var sortButton: some View {
        Menu {
            ForEach(QueueSortOrder.allCases) { sortOrder in
                Button {
                    queueViewModel.sortOrder = sortOrder
                } label: {
                    Label(
                        sortOrder.displayName,
                        systemImage: sortOrder == queueViewModel.sortOrder ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .help("Sort Queues")
    }

    /// Refresh button
    private var refreshButton: some View {
        Button {
            Task {
                try? await queueViewModel.refresh()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh Queues (⌘R)")
        .keyboardShortcut("r", modifiers: .command)
        .disabled(queueViewModel.isLoading)
    }

    /// Filter options button (show/hide system queues)
    private var filterButton: some View {
        Menu {
            Toggle(isOn: $queueViewModel.showSystemQueues) {
                Label("Show System Queues", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: queueViewModel.showSystemQueues ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .help("Filter Options")
    }

    /// Context menu for queue row
    @ViewBuilder
    private func queueContextMenu(for queue: Queue) -> some View {
        if queue.isBrowsable {
            Button {
                selection = queue.id
            } label: {
                Label("Browse Messages", systemImage: "doc.text.magnifyingglass")
            }

            Divider()
        }

        Button {
            Task {
                try? await queueViewModel.refresh()
            }
        } label: {
            Label("Refresh Queue List", systemImage: "arrow.clockwise")
        }

        Divider()

        // Queue info section
        Text("Type: \(queue.queueType.displayName)")
        Text("Depth: \(queue.depthDisplayString)")

        if queue.isInUse {
            Text("In use by \(queue.totalOpenCount) app\(queue.totalOpenCount == 1 ? "" : "s")")
        }

        if queue.putInhibited || queue.getInhibited {
            Divider()
            if queue.putInhibited {
                Label("Put Inhibited", systemImage: "arrow.down.circle.dotted")
            }
            if queue.getInhibited {
                Label("Get Inhibited", systemImage: "arrow.up.circle.dotted")
            }
        }

        // Destructive actions section
        Divider()

        // Purge queue option (only for local queues with messages)
        if queue.queueType == .local && queue.hasMessages {
            Button(role: .destructive) {
                queueToPurge = queue
                showPurgeConfirmation = true
            } label: {
                Label("Purge All Messages...", systemImage: "trash")
            }
            .disabled(isOperationInProgress)
        }

        // Delete queue option (only for local queues)
        if queue.queueType == .local {
            Button(role: .destructive) {
                queueToDelete = queue
                showDeleteConfirmation = true
            } label: {
                Label("Delete Queue...", systemImage: "xmark.bin")
            }
            .disabled(isOperationInProgress || queue.isInUse)
        }
    }

    // MARK: - Confirmation Dialog Buttons

    /// Purge confirmation buttons
    @ViewBuilder
    private func purgeConfirmationButtons(for queue: Queue) -> some View {
        Button("Purge \(queue.depth) Message\(queue.depth == 1 ? "" : "s")", role: .destructive) {
            Task {
                await performPurgeQueue(queue)
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    /// Delete confirmation buttons
    @ViewBuilder
    private func deleteConfirmationButtons(for queue: Queue) -> some View {
        Button("Delete Queue", role: .destructive) {
            Task {
                await performDeleteQueue(queue)
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Destructive Actions

    /// Perform queue purge with audit logging
    private func performPurgeQueue(_ queue: Queue) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            let messageCount = try await queueViewModel.purgeQueue(queueName: queue.name)

            // Log to audit service
            AuditService.shared.logQueuePurged(
                queueName: queue.name,
                messageCount: messageCount,
                queueManager: queueManagerName,
                username: nil
            )

            // Refresh queue list to reflect changes
            try? await queueViewModel.refresh()
        } catch {
            // Error is already handled by QueueViewModel (sets lastError and showErrorAlert)
        }
    }

    /// Perform queue delete with audit logging
    private func performDeleteQueue(_ queue: Queue) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        // Clear selection if deleting the selected queue
        if selection == queue.id {
            selection = nil
        }

        do {
            try await queueViewModel.deleteQueue(queueName: queue.name)

            // Log to audit service
            AuditService.shared.logQueueDeleted(
                queueName: queue.name,
                queueManager: queueManagerName,
                username: nil
            )

            // Refresh queue list to reflect changes
            try? await queueViewModel.refresh()
        } catch {
            // Error is already handled by QueueViewModel (sets lastError and showErrorAlert)
        }
    }

    /// Perform queue create with audit logging
    private func performCreateQueue(name: String, type: MQQueueType) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await queueViewModel.createQueue(queueName: name, queueType: type)

            // Log to audit service
            AuditService.shared.logQueueCreated(
                queueName: name,
                queueType: type.displayName,
                queueManager: queueManagerName,
                username: nil
            )
        } catch {
            // Error is already handled by QueueViewModel (sets lastError and showErrorAlert)
        }
    }
}

// MARK: - Previews
// Note: QueueRowView and CapacityBar are defined in MQMate/Views/Components/QueueRowView.swift

#Preview("With Queues") {
    @Previewable @State var selection: String? = nil

    NavigationSplitView {
        Text("Connections")
            .frame(width: 200)
    } content: {
        QueueListView(
            queueViewModel: QueueViewModel.preview,
            selection: $selection
        )
        .frame(minWidth: 300)
    } detail: {
        Text("Select a queue")
    }
    .frame(width: 900, height: 600)
}

#Preview("Empty State") {
    @Previewable @State var selection: String? = nil

    NavigationSplitView {
        Text("Connections")
            .frame(width: 200)
    } content: {
        QueueListView(
            queueViewModel: QueueViewModel.previewEmpty,
            selection: $selection
        )
        .frame(minWidth: 300)
    } detail: {
        Text("Select a queue")
    }
    .frame(width: 900, height: 600)
}
