import Foundation
import SwiftUI

// MARK: - MessageViewModel

/// ViewModel for managing message browsing and display
/// Provides message data for the MessageBrowserView with filtering, sorting, and selection
@Observable
@MainActor
public final class MessageViewModel {

    // MARK: - Properties

    /// All messages loaded from the queue (via browse operation)
    public private(set) var messages: [Message] = []

    /// Currently selected message ID
    public var selectedMessageId: String?

    /// Loading state for message browse operations
    public private(set) var isLoading: Bool = false

    /// Name of the currently browsed queue
    public private(set) var currentQueueName: String?

    /// Search/filter text for filtering the message list
    public var searchText: String = ""

    /// Current sort order for the message list
    public var sortOrder: MessageSortOrder = .position

    /// Whether to show message payload preview in the list
    public var showPayloadPreview: Bool = true

    /// Maximum number of messages to browse at once
    public var maxMessagesToLoad: Int = 100

    /// Last error encountered during operations
    public private(set) var lastError: Error?

    /// Show error alert flag
    public var showErrorAlert: Bool = false

    /// Timestamp of the last successful message refresh
    public private(set) var lastRefreshDate: Date?

    // MARK: - Dependencies

    /// MQ service for message operations
    private let mqService: MQServiceProtocol

    // MARK: - Computed Properties

    /// Currently selected message
    public var selectedMessage: Message? {
        guard let id = selectedMessageId else { return nil }
        return messages.first { $0.id == id }
    }

    /// Filtered and sorted messages for display
    public var filteredMessages: [Message] {
        var result = messages

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { message in
                // Search in message ID
                message.messageIdHex.lowercased().contains(searchLower) ||
                // Search in payload (if text)
                (message.payloadString?.lowercased().contains(searchLower) ?? false) ||
                // Search in put application name
                message.putApplicationName.lowercased().contains(searchLower) ||
                // Search in format
                message.format.lowercased().contains(searchLower) ||
                // Search in reply-to queue
                message.replyToQueue.lowercased().contains(searchLower)
            }
        }

        // Apply sort order
        result = sortMessages(result)

        return result
    }

    /// Number of messages matching current filters
    public var filteredMessageCount: Int {
        filteredMessages.count
    }

    /// Total number of messages (before filtering)
    public var totalMessageCount: Int {
        messages.count
    }

    /// Total payload size across all messages
    public var totalPayloadSize: Int64 {
        messages.reduce(0) { $0 + Int64($1.payloadSize) }
    }

    /// Formatted total payload size for display
    public var totalPayloadSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalPayloadSize, countStyle: .file)
    }

    /// Number of persistent messages
    public var persistentMessageCount: Int {
        messages.filter { $0.persistence == .persistent }.count
    }

    /// Number of request messages (waiting for reply)
    public var requestMessageCount: Int {
        messages.filter { $0.messageType == .request }.count
    }

    /// Check if the message list is empty
    public var isEmpty: Bool {
        messages.isEmpty
    }

    /// Check if there are no results matching the current filter
    public var isFilteredEmpty: Bool {
        !messages.isEmpty && filteredMessages.isEmpty
    }

    /// Check if currently browsing a queue
    public var hasBrowsedQueue: Bool {
        currentQueueName != nil
    }

    /// Summary text for the current message list state
    public var summaryText: String {
        if isLoading {
            return "Loading messages..."
        }

        guard hasBrowsedQueue else {
            return "Select a queue to browse messages"
        }

        if isEmpty {
            return "No messages in queue"
        }

        let total = totalMessageCount
        let filtered = filteredMessageCount

        if filtered == total {
            return "\(total) message\(total == 1 ? "" : "s"), \(totalPayloadSizeFormatted)"
        } else {
            return "\(filtered) of \(total) message\(total == 1 ? "" : "s")"
        }
    }

    /// Index of the currently selected message in the filtered list
    public var selectedMessageIndex: Int? {
        guard let id = selectedMessageId else { return nil }
        return filteredMessages.firstIndex { $0.id == id }
    }

    // MARK: - Initialization

    /// Create a new MessageViewModel with dependencies
    /// - Parameter mqService: MQ service for message operations (defaults to new instance)
    public init(mqService: MQServiceProtocol? = nil) {
        self.mqService = mqService ?? MQService()
    }

    // MARK: - Message Browsing

    /// Browse messages in a queue without removing them
    /// - Parameters:
    ///   - queueName: Name of the queue to browse
    ///   - maxMessages: Maximum number of messages to browse (defaults to maxMessagesToLoad)
    /// - Throws: MQError if browsing fails
    public func browseMessages(queueName: String, maxMessages: Int? = nil) async throws {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        currentQueueName = queueName

        defer {
            isLoading = false
        }

        do {
            let limit = maxMessages ?? maxMessagesToLoad
            let mqMessages = try await mqService.browseMessages(
                queueName: queueName,
                maxMessages: limit
            )

            // Convert MQService.MQMessage to Message model
            let messageModels = mqMessages.map { mqMessage in
                Message(
                    messageId: mqMessage.messageId,
                    correlationId: mqMessage.correlationId,
                    format: mqMessage.format,
                    payload: mqMessage.payload,
                    putDateTime: mqMessage.putDateTime,
                    putApplicationName: mqMessage.putApplicationName,
                    messageType: MessageType(rawValue: mqMessage.messageType.rawValue),
                    persistence: MessagePersistence(rawValue: mqMessage.persistence.rawValue),
                    priority: mqMessage.priority,
                    replyToQueue: mqMessage.replyToQueue,
                    replyToQueueManager: mqMessage.replyToQueueManager,
                    messageSequenceNumber: mqMessage.messageSequenceNumber,
                    position: mqMessage.position
                )
            }

            messages = messageModels
            lastRefreshDate = Date()

            // Auto-select first message if nothing is selected
            if selectedMessageId == nil && !messages.isEmpty {
                selectedMessageId = messages.first?.id
            }

        } catch {
            lastError = error
            showErrorAlert = true
            throw error
        }
    }

    /// Refresh messages for the current queue
    /// - Throws: MQError if refresh fails
    public func refresh() async throws {
        guard let queueName = currentQueueName else { return }
        try await browseMessages(queueName: queueName)
    }

    /// Set messages directly (useful for testing and preview)
    /// - Parameters:
    ///   - messages: Array of Message objects
    ///   - queueName: Optional queue name to set as current
    public func setMessages(_ messages: [Message], queueName: String? = nil) {
        self.messages = messages
        self.currentQueueName = queueName
        self.lastRefreshDate = Date()
    }

    /// Clear all messages and reset state
    public func clearMessages() {
        messages = []
        selectedMessageId = nil
        currentQueueName = nil
        lastRefreshDate = nil
    }

    // MARK: - Selection Management

    /// Select a message by ID
    /// - Parameter id: The message ID to select
    public func selectMessage(id: String?) {
        selectedMessageId = id
    }

    /// Select a message by index in the filtered list
    /// - Parameter index: Index in the filtered messages array
    public func selectMessage(at index: Int) {
        let filtered = filteredMessages
        guard index >= 0 && index < filtered.count else { return }
        selectedMessageId = filtered[index].id
    }

    /// Select the next message in the filtered list
    public func selectNextMessage() {
        let filtered = filteredMessages
        guard !filtered.isEmpty else { return }

        if let currentId = selectedMessageId,
           let currentIndex = filtered.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % filtered.count
            selectedMessageId = filtered[nextIndex].id
        } else {
            selectedMessageId = filtered.first?.id
        }
    }

    /// Select the previous message in the filtered list
    public func selectPreviousMessage() {
        let filtered = filteredMessages
        guard !filtered.isEmpty else { return }

        if let currentId = selectedMessageId,
           let currentIndex = filtered.firstIndex(where: { $0.id == currentId }) {
            let previousIndex = currentIndex == 0 ? filtered.count - 1 : currentIndex - 1
            selectedMessageId = filtered[previousIndex].id
        } else {
            selectedMessageId = filtered.last?.id
        }
    }

    /// Select the first message in the filtered list
    public func selectFirstMessage() {
        selectedMessageId = filteredMessages.first?.id
    }

    /// Select the last message in the filtered list
    public func selectLastMessage() {
        selectedMessageId = filteredMessages.last?.id
    }

    // MARK: - Filtering

    /// Get messages of a specific type
    /// - Parameter type: The message type to filter by
    /// - Returns: Filtered array of messages
    public func messages(ofType type: MessageType) -> [Message] {
        filteredMessages.filter { $0.messageType == type }
    }

    /// Get persistent messages
    /// - Returns: Array of persistent messages
    public func persistentMessages() -> [Message] {
        filteredMessages.filter { $0.persistence == .persistent }
    }

    /// Get messages with a specific format
    /// - Parameter format: The message format to filter by
    /// - Returns: Array of messages matching the format
    public func messages(withFormat format: MessageFormat) -> [Message] {
        filteredMessages.filter { $0.messageFormat == format }
    }

    /// Get messages with correlation IDs (part of request/reply patterns)
    /// - Returns: Array of messages that have correlation IDs set
    public func messagesWithCorrelationId() -> [Message] {
        filteredMessages.filter { $0.hasCorrelationId }
    }

    /// Get messages within a date range
    /// - Parameters:
    ///   - from: Start date (inclusive)
    ///   - to: End date (inclusive)
    /// - Returns: Array of messages within the date range
    public func messages(from: Date, to: Date) -> [Message] {
        filteredMessages.filter { message in
            guard let putDate = message.putDateTime else { return false }
            return putDate >= from && putDate <= to
        }
    }

    /// Clear the search filter
    public func clearSearch() {
        searchText = ""
    }

    // MARK: - Sorting

    /// Apply the current sort order to an array of messages
    /// - Parameter messages: Messages to sort
    /// - Returns: Sorted array of messages
    private func sortMessages(_ messages: [Message]) -> [Message] {
        switch sortOrder {
        case .position:
            return messages.sorted { $0.position < $1.position }
        case .positionDescending:
            return messages.sorted { $0.position > $1.position }
        case .dateTime:
            return messages.sorted { (m1, m2) in
                guard let d1 = m1.putDateTime else { return false }
                guard let d2 = m2.putDateTime else { return true }
                return d1 < d2
            }
        case .dateTimeDescending:
            return messages.sorted { (m1, m2) in
                guard let d1 = m1.putDateTime else { return true }
                guard let d2 = m2.putDateTime else { return false }
                return d1 > d2
            }
        case .size:
            return messages.sorted { $0.payloadSize > $1.payloadSize }
        case .sizeAscending:
            return messages.sorted { $0.payloadSize < $1.payloadSize }
        case .priority:
            return messages.sorted { $0.priority > $1.priority }
        case .messageId:
            return messages.sorted { $0.messageIdHex < $1.messageIdHex }
        }
    }

    /// Cycle to the next sort order
    public func cycleSortOrder() {
        sortOrder = sortOrder.next
    }

    // MARK: - Message Details

    /// Get message at a specific position
    /// - Parameter position: Position in the queue (0-based)
    /// - Returns: Message at the position, or nil if not found
    public func message(atPosition position: Int) -> Message? {
        messages.first { $0.position == position }
    }

    /// Get message by ID
    /// - Parameter id: Message ID (hex string)
    /// - Returns: Message with the ID, or nil if not found
    public func message(withId id: String) -> Message? {
        messages.first { $0.id == id }
    }

    // MARK: - Error Handling

    /// Clear the last error
    public func clearError() {
        lastError = nil
        showErrorAlert = false
    }
}

// MARK: - MessageSortOrder

/// Sort order options for the message list
public enum MessageSortOrder: String, CaseIterable, Identifiable {
    case position = "Position (First-Last)"
    case positionDescending = "Position (Last-First)"
    case dateTime = "Time (Oldest-Newest)"
    case dateTimeDescending = "Time (Newest-Oldest)"
    case size = "Size (Large-Small)"
    case sizeAscending = "Size (Small-Large)"
    case priority = "Priority (High-Low)"
    case messageId = "Message ID"

    public var id: String { rawValue }

    /// Display name for the sort order
    public var displayName: String { rawValue }

    /// SF Symbol for the sort order
    public var systemImageName: String {
        switch self {
        case .position, .positionDescending:
            return "list.number"
        case .dateTime, .dateTimeDescending:
            return "clock"
        case .size, .sizeAscending:
            return "doc"
        case .priority:
            return "exclamationmark.circle"
        case .messageId:
            return "number"
        }
    }

    /// Get the next sort order in the cycle
    public var next: MessageSortOrder {
        let allCases = MessageSortOrder.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return .position
        }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - Preview Support

extension MessageViewModel {

    /// Create a MessageViewModel with sample data for SwiftUI previews
    public static var preview: MessageViewModel {
        let viewModel = MessageViewModel(mqService: PreviewMessageMQService())
        viewModel.messages = Message.samples
        viewModel.currentQueueName = "DEV.QUEUE.1"
        viewModel.lastRefreshDate = Date()
        viewModel.selectedMessageId = Message.samples.first?.id
        return viewModel
    }

    /// Create a MessageViewModel in loading state for SwiftUI previews
    public static var previewLoading: MessageViewModel {
        let viewModel = MessageViewModel(mqService: PreviewMessageMQService())
        viewModel.messages = []
        viewModel.currentQueueName = "DEV.QUEUE.1"
        // Note: isLoading cannot be directly set; for previews, use the view's state
        return viewModel
    }

    /// Create an empty MessageViewModel for SwiftUI previews
    public static var previewEmpty: MessageViewModel {
        let viewModel = MessageViewModel(mqService: PreviewMessageMQService())
        viewModel.messages = []
        viewModel.currentQueueName = "DEV.QUEUE.1"
        return viewModel
    }

    /// Create a MessageViewModel with error state for SwiftUI previews
    public static var previewWithError: MessageViewModel {
        let viewModel = MessageViewModel(mqService: PreviewMessageMQService())
        viewModel.lastError = MQError.notConnected
        viewModel.showErrorAlert = true
        return viewModel
    }

    /// Create a MessageViewModel with no queue selected for SwiftUI previews
    public static var previewNoQueue: MessageViewModel {
        let viewModel = MessageViewModel(mqService: PreviewMessageMQService())
        viewModel.messages = []
        viewModel.currentQueueName = nil
        return viewModel
    }
}

// MARK: - PreviewMessageMQService

/// Mock MQ service for preview and testing purposes
@MainActor
private final class PreviewMessageMQService: MQServiceProtocol {

    var isConnected: Bool = true

    func connect(
        queueManager: String,
        channel: String,
        host: String,
        port: Int,
        username: String?,
        password: String?
    ) async throws {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func getQueueInfo(queueName: String) throws -> MQService.QueueInfo {
        MQService.QueueInfo(
            name: queueName,
            queueType: .local,
            currentDepth: 42,
            maxDepth: 5000
        )
    }

    func listQueues(filter: String) async throws -> [MQService.QueueInfo] {
        [
            MQService.QueueInfo(name: "DEV.QUEUE.1", queueType: .local, currentDepth: 5, maxDepth: 5000),
            MQService.QueueInfo(name: "DEV.QUEUE.2", queueType: .local, currentDepth: 0, maxDepth: 5000),
            MQService.QueueInfo(name: "DEV.QUEUE.3", queueType: .local, currentDepth: 142, maxDepth: 5000)
        ]
    }

    func createQueue(queueName: String, queueType: MQQueueType, maxDepth: Int32?) async throws {
        // Mock implementation - does nothing
    }

    func browseMessages(queueName: String, maxMessages: Int) async throws -> [MQService.MQMessage] {
        // Return sample messages converted to MQService.MQMessage format
        return Message.samples.prefix(maxMessages).map { message in
            MQService.MQMessage(
                messageId: message.messageId,
                correlationId: message.correlationId,
                format: message.format,
                payload: message.payload,
                putDateTime: message.putDateTime,
                putApplicationName: message.putApplicationName,
                messageType: MQService.MQMessageType(rawValue: message.messageType.rawValue),
                persistence: MQService.MQMessagePersistence(rawValue: message.persistence.rawValue),
                priority: message.priority,
                replyToQueue: message.replyToQueue,
                replyToQueueManager: message.replyToQueueManager,
                messageSequenceNumber: message.messageSequenceNumber,
                position: message.position
            )
        }
    }
}

// MARK: - MQServiceProtocol Extension

extension MQServiceProtocol {
    /// Default implementation of browseMessages for protocols that don't implement it
    func browseMessages(queueName: String, maxMessages: Int) async throws -> [MQService.MQMessage] {
        // Default implementation throws notConnected
        throw MQError.notConnected
    }
}
