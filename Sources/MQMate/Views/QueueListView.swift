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

    /// Show sort picker popover
    @State private var showSortPicker = false

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
                sortButton
                refreshButton
                filterButton
            }
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
