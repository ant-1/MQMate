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
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading queues...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Empty state when no queues exist
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Queues", systemImage: "tray")
        } description: {
            Text("This queue manager has no queues, or you don't have permission to view them.")
        } actions: {
            Button {
                Task {
                    try? await queueViewModel.refresh()
                }
            } label: {
                Text("Refresh")
            }
            .buttonStyle(.borderedProminent)
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

// MARK: - QueueRowView

/// Row view for displaying a single queue in the list
struct QueueRowView: View {

    /// Queue to display
    let queue: Queue

    var body: some View {
        HStack(spacing: 12) {
            // Queue type icon
            queueTypeIcon

            // Queue details
            VStack(alignment: .leading, spacing: 2) {
                Text(queue.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(queue.queueType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let description = queue.queueDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Depth indicator
            depthIndicator
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(queue.accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// Queue type icon with state coloring
    private var queueTypeIcon: some View {
        Image(systemName: queue.stateSystemImageName)
            .foregroundStyle(iconColor)
            .imageScale(.medium)
            .frame(width: 20, height: 20)
    }

    /// Color for the queue icon based on state
    private var iconColor: Color {
        switch queue.stateColorName {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        default:
            return .secondary
        }
    }

    /// Depth indicator badge
    @ViewBuilder
    private var depthIndicator: some View {
        if queue.hasMessages || queue.maxDepth > 0 {
            VStack(alignment: .trailing, spacing: 2) {
                // Message count
                Text(queue.depthShortString)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(depthColor)

                // Capacity bar (if local queue)
                if queue.queueType == .local && queue.maxDepth > 0 {
                    CapacityBar(percentage: queue.depthPercentage)
                        .frame(width: 50, height: 4)
                }
            }
        }
    }

    /// Color for the depth text based on capacity
    private var depthColor: Color {
        if queue.isFull || queue.isCriticalCapacity {
            return .red
        } else if queue.isNearCapacity {
            return .orange
        } else if queue.hasMessages {
            return .primary
        } else {
            return .secondary
        }
    }

    /// Accessibility hint for the row
    private var accessibilityHint: String {
        if queue.isBrowsable {
            return "Double-click to browse messages. Right-click for options."
        } else {
            return "Right-click for queue information."
        }
    }
}

// MARK: - CapacityBar

/// Small capacity indicator bar showing queue fill percentage
struct CapacityBar: View {
    let percentage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * min(percentage, 1.0))
            }
        }
    }

    private var fillColor: Color {
        if percentage >= 0.95 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else if percentage >= 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Previews

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

#Preview("Queue Row - Normal") {
    List {
        QueueRowView(queue: Queue.sample)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Near Capacity") {
    List {
        QueueRowView(queue: Queue.sampleNearCapacity)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Full") {
    List {
        QueueRowView(queue: Queue.sampleFull)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Empty") {
    List {
        QueueRowView(queue: Queue.sampleEmpty)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Inhibited") {
    List {
        QueueRowView(queue: Queue.sampleInhibited)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Alias") {
    List {
        QueueRowView(queue: Queue.sampleAlias)
    }
    .frame(width: 300, height: 80)
}

#Preview("Capacity Bar") {
    VStack(spacing: 10) {
        CapacityBar(percentage: 0.25)
            .frame(width: 50, height: 4)
        CapacityBar(percentage: 0.5)
            .frame(width: 50, height: 4)
        CapacityBar(percentage: 0.8)
            .frame(width: 50, height: 4)
        CapacityBar(percentage: 0.95)
            .frame(width: 50, height: 4)
        CapacityBar(percentage: 1.0)
            .frame(width: 50, height: 4)
    }
    .padding()
}
