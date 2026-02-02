import SwiftUI

// MARK: - MessageBrowserView

/// Detail column view displaying messages for a selected queue
/// Shows message list with selection support, filtering, and sorting
/// Displays message details in a split view when a message is selected
struct MessageBrowserView: View {

    // MARK: - Properties

    /// The message view model providing message data and operations
    @Bindable var messageViewModel: MessageViewModel

    /// The name of the queue being browsed
    let queueName: String

    /// Binding to the selected message ID
    @Binding var selection: String?

    /// Show sort picker popover
    @State private var showSortPicker = false

    /// Inspector visibility for message detail
    @State private var showInspector = true

    // MARK: - Body

    var body: some View {
        Group {
            if messageViewModel.isLoading {
                loadingView
            } else if !messageViewModel.hasBrowsedQueue {
                selectQueueView
            } else if messageViewModel.isEmpty {
                emptyStateView
            } else if messageViewModel.isFilteredEmpty {
                noResultsView
            } else {
                messageListView
            }
        }
        .navigationTitle(queueName)
        .navigationSubtitle(messageViewModel.summaryText)
        .searchable(
            text: $messageViewModel.searchText,
            placement: .toolbar,
            prompt: "Filter messages"
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                sortButton
                refreshButton
                inspectorToggle
            }
        }
        .inspector(isPresented: $showInspector) {
            messageDetailView
                .inspectorColumnWidth(min: 300, ideal: 400, max: 600)
        }
        .task {
            // Load messages when view appears if not already loaded
            if messageViewModel.currentQueueName != queueName {
                try? await messageViewModel.browseMessages(queueName: queueName)
            }
        }
        .onChange(of: selection) { _, newValue in
            messageViewModel.selectMessage(id: newValue)
        }
        .onChange(of: messageViewModel.selectedMessageId) { _, newValue in
            if selection != newValue {
                selection = newValue
            }
        }
        .alert(
            "Error Loading Messages",
            isPresented: $messageViewModel.showErrorAlert,
            presenting: messageViewModel.lastError
        ) { _ in
            Button("OK") {
                messageViewModel.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Subviews

    /// Main message list
    private var messageListView: some View {
        List(selection: $selection) {
            ForEach(messageViewModel.filteredMessages) { message in
                MessageRowView(message: message)
                    .tag(message.id)
                    .contextMenu {
                        messageContextMenu(for: message)
                    }
            }
        }
        .listStyle(.inset)
        .refreshable {
            try? await messageViewModel.refresh()
        }
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    /// Loading indicator
    private var loadingView: some View {
        LoadingView("Loading messages...")
    }

    /// Empty state when no messages exist in the queue
    private var emptyStateView: some View {
        EmptyStateView.noMessages {
            Task {
                try? await messageViewModel.refresh()
            }
        }
    }

    /// View for when no queue is selected
    private var selectQueueView: some View {
        EmptyStateView.selectQueue()
    }

    /// No results when filter matches nothing
    private var noResultsView: some View {
        ContentUnavailableView.search(text: messageViewModel.searchText)
    }

    /// Message detail view shown in inspector
    @ViewBuilder
    private var messageDetailView: some View {
        if let message = messageViewModel.selectedMessage {
            MessageDetailView(message: message)
        } else {
            ContentUnavailableView {
                Label("No Message Selected", systemImage: "doc.text")
            } description: {
                Text("Select a message to view its details")
            }
        }
    }

    /// Status bar at bottom showing summary
    private var statusBar: some View {
        HStack {
            // Message count and size
            if messageViewModel.filteredMessageCount != messageViewModel.totalMessageCount {
                Text("\(messageViewModel.filteredMessageCount) of \(messageViewModel.totalMessageCount) messages")
            } else {
                Text("\(messageViewModel.totalMessageCount) message\(messageViewModel.totalMessageCount == 1 ? "" : "s")")
            }

            Text("\u{2022}")
                .foregroundStyle(.tertiary)

            Text(messageViewModel.totalPayloadSizeFormatted)

            Spacer()

            if let date = messageViewModel.lastRefreshDate {
                Text("Updated \(date, style: .relative)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Sort order button
    private var sortButton: some View {
        Menu {
            ForEach(MessageSortOrder.allCases) { sortOrder in
                Button {
                    messageViewModel.sortOrder = sortOrder
                } label: {
                    Label(
                        sortOrder.displayName,
                        systemImage: sortOrder == messageViewModel.sortOrder ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .help("Sort Messages")
    }

    /// Refresh button
    private var refreshButton: some View {
        Button {
            Task {
                try? await messageViewModel.refresh()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh Messages (⌘R)")
        .keyboardShortcut("r", modifiers: .command)
        .disabled(messageViewModel.isLoading)
    }

    /// Toggle inspector visibility
    private var inspectorToggle: some View {
        Button {
            showInspector.toggle()
        } label: {
            Image(systemName: showInspector ? "sidebar.trailing" : "sidebar.trailing.badge.plus")
        }
        .help(showInspector ? "Hide Inspector" : "Show Inspector")
        .keyboardShortcut("i", modifiers: [.command, .option])
    }

    /// Context menu for message row
    @ViewBuilder
    private func messageContextMenu(for message: Message) -> some View {
        Button {
            selection = message.id
            showInspector = true
        } label: {
            Label("View Details", systemImage: "doc.text.magnifyingglass")
        }

        Button {
            copyToClipboard(message.messageIdHex)
        } label: {
            Label("Copy Message ID", systemImage: "doc.on.doc")
        }

        if let payloadString = message.payloadString, !message.isBinaryPayload {
            Button {
                copyToClipboard(payloadString)
            } label: {
                Label("Copy Payload", systemImage: "doc.on.clipboard")
            }
        }

        Divider()

        // Message info section
        Text("Position: #\(message.position + 1)")
        Text("Type: \(message.messageType.displayName)")
        Text("Format: \(message.messageFormat.displayName)")
        Text("Size: \(message.payloadSizeFormatted)")

        if message.hasReplyTo {
            Divider()
            Text("Reply To: \(message.replyToDestination)")
        }

        if message.persistence == .persistent {
            Divider()
            Label("Persistent", systemImage: "externaldrive.fill")
        }
    }

    // MARK: - Actions

    /// Copy text to the system clipboard
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - MessageRowView

/// Row view for displaying a single message in the list
/// Shows message ID, type icon, timestamp, size, and payload preview
struct MessageRowView: View {

    // MARK: - Properties

    /// The message to display
    let message: Message

    /// Whether to show payload preview
    var showPayloadPreview: Bool = true

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Message type icon
            Image(systemName: message.typeSystemImageName)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 24)

            // Message info
            VStack(alignment: .leading, spacing: 2) {
                // Message ID (short) and timestamp
                HStack {
                    Text(message.messageIdShort)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text(message.putDateTimeRelative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Format, size, and persistence indicator
                HStack(spacing: 8) {
                    Text(message.messageFormat.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\u{2022}")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(message.payloadSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if message.persistence == .persistent {
                        Image(systemName: "externaldrive.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if message.hasReplyTo {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Priority badge for high priority messages
                    if message.priority >= 7 {
                        Text("P\(message.priority)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(message.priority == 9 ? Color.red : Color.orange)
                            .clipShape(Capsule())
                    }
                }

                // Payload preview (if text and enabled)
                if showPayloadPreview, let preview = payloadPreviewText {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.accessibilityLabel)
        .accessibilityHint("Double-click to view message details")
    }

    // MARK: - Computed Properties

    /// Icon color based on message type
    private var iconColor: Color {
        switch message.messageType {
        case .request:
            return .blue
        case .reply:
            return .green
        case .report:
            return .orange
        case .datagram:
            return .secondary
        case .unknown:
            return .gray
        }
    }

    /// Payload preview text (first line of text payload)
    private var payloadPreviewText: String? {
        guard !message.isBinaryPayload,
              let text = message.payloadString else {
            return nil
        }

        // Get first meaningful line
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let preview = String(firstLine.prefix(100))

        return preview.isEmpty ? nil : preview
    }
}

// MARK: - MessageDetailView

/// Detail view showing full message information including headers and payload
struct MessageDetailView: View {

    // MARK: - Properties

    /// The message to display details for
    let message: Message

    /// Currently selected payload view mode
    @State private var payloadViewMode: PayloadViewMode = .text

    /// Whether hex dump is being displayed
    @State private var showHexDump = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Message header info
                headerSection

                Divider()

                // Message metadata
                metadataSection

                Divider()

                // Payload section
                payloadSection
            }
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Sections

    /// Message header section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message ID
            LabeledContent {
                Text(message.messageIdHex)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } label: {
                Label("Message ID", systemImage: "number")
            }

            // Correlation ID (if set)
            if message.hasCorrelationId {
                LabeledContent {
                    Text(message.correlationIdHex)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } label: {
                    Label("Correlation ID", systemImage: "link")
                }
            }

            // Put timestamp
            if let putDate = message.putDateTime {
                LabeledContent {
                    VStack(alignment: .trailing) {
                        Text(message.putDateTimeFormatted)
                        Text(message.putDateTimeRelative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Put Time", systemImage: "clock")
                }
            }

            // Put application
            if !message.putApplicationName.isEmpty {
                LabeledContent {
                    Text(message.putApplicationName)
                        .textSelection(.enabled)
                } label: {
                    Label("Application", systemImage: "app")
                }
            }
        }
    }

    /// Message metadata section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                // Type
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(message.messageType.displayName, systemImage: message.typeSystemImageName)
                }

                // Format
                VStack(alignment: .leading, spacing: 4) {
                    Text("Format")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.messageFormat.displayName)
                }

                // Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.payloadSizeFormatted)
                }

                // Persistence
                VStack(alignment: .leading, spacing: 4) {
                    Text("Persistence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(message.persistence.displayName, systemImage: message.persistenceSystemImageName)
                }
            }

            HStack(spacing: 24) {
                // Priority
                VStack(alignment: .leading, spacing: 4) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.priorityDisplayString)
                }

                // Position
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("#\(message.position + 1)")
                }

                // Reply-to (if set)
                if message.hasReplyTo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reply To")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(message.replyToDestination)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    /// Payload section with view mode toggle
    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Payload")
                    .font(.headline)

                Spacer()

                Picker("View Mode", selection: $payloadViewMode) {
                    Text("Text").tag(PayloadViewMode.text)
                    Text("Hex").tag(PayloadViewMode.hex)
                    Text("JSON").tag(PayloadViewMode.json)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            payloadContentView
        }
    }

    /// Payload content based on selected view mode
    @ViewBuilder
    private var payloadContentView: some View {
        switch payloadViewMode {
        case .text:
            if let text = message.payloadString, !message.isBinaryPayload {
                TextEditor(text: .constant(text))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.3))
            } else {
                VStack {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Binary content - switch to Hex view")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

        case .hex:
            ScrollView([.horizontal, .vertical]) {
                Text(message.payloadHexDump)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(minHeight: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color.gray.opacity(0.3))

        case .json:
            if let jsonText = formatAsJSON(message.payloadString) {
                TextEditor(text: .constant(jsonText))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.3))
            } else {
                VStack {
                    Image(systemName: "curlybraces")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Not valid JSON")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helpers

    /// Attempt to format string as pretty-printed JSON
    private func formatAsJSON(_ text: String?) -> String? {
        guard let text = text,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }
}

// MARK: - PayloadViewMode

/// View mode options for message payload display
enum PayloadViewMode: String, CaseIterable {
    case text = "Text"
    case hex = "Hex"
    case json = "JSON"
}

// MARK: - Previews

#Preview("With Messages") {
    @Previewable @State var selection: String? = nil

    NavigationSplitView {
        Text("Connections")
            .frame(width: 200)
    } content: {
        Text("Queues")
            .frame(width: 200)
    } detail: {
        MessageBrowserView(
            messageViewModel: MessageViewModel.preview,
            queueName: "DEV.QUEUE.1",
            selection: $selection
        )
    }
    .frame(width: 1200, height: 700)
}

#Preview("Empty Queue") {
    @Previewable @State var selection: String? = nil

    NavigationSplitView {
        Text("Connections")
            .frame(width: 200)
    } content: {
        Text("Queues")
            .frame(width: 200)
    } detail: {
        MessageBrowserView(
            messageViewModel: MessageViewModel.previewEmpty,
            queueName: "DEV.QUEUE.EMPTY",
            selection: $selection
        )
    }
    .frame(width: 1200, height: 700)
}

#Preview("Message Row - Text") {
    MessageRowView(message: Message.sampleText)
        .frame(width: 400)
        .padding()
}

#Preview("Message Row - JSON") {
    MessageRowView(message: Message.sampleJSON)
        .frame(width: 400)
        .padding()
}

#Preview("Message Row - Binary") {
    MessageRowView(message: Message.sampleBinary)
        .frame(width: 400)
        .padding()
}

#Preview("Message Detail") {
    MessageDetailView(message: Message.sampleJSON)
        .frame(width: 400, height: 600)
}
