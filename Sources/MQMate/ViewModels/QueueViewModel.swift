import Foundation
import SwiftUI

// MARK: - QueueViewModel

/// ViewModel for managing queue listing and refresh operations
/// Provides queue data for the QueueListView with filtering, sorting, and selection
@Observable
@MainActor
public final class QueueViewModel {

    // MARK: - Properties

    /// All queues loaded from the queue manager
    public private(set) var queues: [Queue] = []

    /// Currently selected queue ID
    public var selectedQueueId: String?

    /// Loading state for queue list operations
    public private(set) var isLoading: Bool = false

    /// Search/filter text for filtering the queue list
    public var searchText: String = ""

    /// Current sort order for the queue list
    public var sortOrder: QueueSortOrder = .name

    /// Whether to show system queues (SYSTEM.* prefix)
    public var showSystemQueues: Bool = false

    /// Last error encountered during operations
    public private(set) var lastError: Error?

    /// Show error alert flag
    public var showErrorAlert: Bool = false

    /// Timestamp of the last successful queue refresh
    public private(set) var lastRefreshDate: Date?

    /// Reference to the active queue manager ID
    private var activeQueueManagerId: UUID?

    // MARK: - Dependencies

    /// MQ service for queue operations
    private let mqService: MQServiceProtocol

    // MARK: - Computed Properties

    /// Currently selected queue
    public var selectedQueue: Queue? {
        guard let id = selectedQueueId else { return nil }
        return queues.first { $0.id == id }
    }

    /// Filtered and sorted queues for display
    public var filteredQueues: [Queue] {
        var result = queues

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { queue in
                queue.name.lowercased().contains(searchLower) ||
                (queue.queueDescription?.lowercased().contains(searchLower) ?? false)
            }
        }

        // Filter system queues if not showing them
        if !showSystemQueues {
            result = result.filter { !$0.name.hasPrefix("SYSTEM.") }
        }

        // Apply sort order
        result = sortQueues(result)

        return result
    }

    /// Number of queues matching current filters
    public var filteredQueueCount: Int {
        filteredQueues.count
    }

    /// Total number of queues (before filtering)
    public var totalQueueCount: Int {
        queues.count
    }

    /// Total message count across all filtered queues
    public var totalMessageCount: Int64 {
        filteredQueues.reduce(0) { $0 + Int64($1.depth) }
    }

    /// Number of queues with messages
    public var queuesWithMessagesCount: Int {
        filteredQueues.filter { $0.hasMessages }.count
    }

    /// Number of queues near or at capacity
    public var queuesNearCapacityCount: Int {
        filteredQueues.filter { $0.isNearCapacity || $0.isCriticalCapacity || $0.isFull }.count
    }

    /// Check if any queue is at critical capacity
    public var hasQueuesAtCriticalCapacity: Bool {
        filteredQueues.contains { $0.isCriticalCapacity || $0.isFull }
    }

    /// Check if the queue list is empty
    public var isEmpty: Bool {
        queues.isEmpty
    }

    /// Check if there are no results matching the current filter
    public var isFilteredEmpty: Bool {
        !queues.isEmpty && filteredQueues.isEmpty
    }

    /// Summary text for the current queue list state
    public var summaryText: String {
        if isLoading {
            return "Loading queues..."
        }

        if isEmpty {
            return "No queues"
        }

        let total = totalQueueCount
        let filtered = filteredQueueCount
        let messages = totalMessageCount

        if filtered == total {
            return "\(total) queue\(total == 1 ? "" : "s"), \(messages) message\(messages == 1 ? "" : "s")"
        } else {
            return "\(filtered) of \(total) queue\(total == 1 ? "" : "s")"
        }
    }

    // MARK: - Initialization

    /// Create a new QueueViewModel with dependencies
    /// - Parameter mqService: MQ service for queue operations (defaults to new instance)
    public init(mqService: MQServiceProtocol? = nil) {
        self.mqService = mqService ?? MQService()
    }

    // MARK: - Queue Loading

    /// Load queues from the MQ service
    /// - Parameter filter: Optional filter pattern (e.g., "DEV.*"). Defaults to "*" for all queues
    /// - Throws: MQError if loading fails
    public func loadQueues(filter: String = "*") async throws {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        defer {
            isLoading = false
        }

        do {
            let queueInfoList = try await mqService.listQueues(filter: filter)

            // Convert QueueInfo to Queue model
            let queueModels = queueInfoList.map { info in
                Queue(
                    name: info.name,
                    queueType: info.queueType,
                    depth: info.currentDepth,
                    maxDepth: info.maxDepth,
                    getInhibited: info.inhibitGet,
                    putInhibited: info.inhibitPut,
                    openInputCount: info.openInputCount,
                    openOutputCount: info.openOutputCount
                )
            }

            queues = queueModels
            lastRefreshDate = Date()

        } catch {
            lastError = error
            showErrorAlert = true
            throw error
        }
    }

    /// Refresh the queue list (re-load with same filter)
    /// - Throws: MQError if refresh fails
    public func refresh() async throws {
        try await loadQueues()
    }

    /// Set queues directly (useful for testing and when loading from ConnectionManager)
    /// - Parameter queues: Array of Queue objects
    public func setQueues(_ queues: [Queue]) {
        self.queues = queues
        self.lastRefreshDate = Date()
    }

    /// Clear all queues
    public func clearQueues() {
        queues = []
        selectedQueueId = nil
        lastRefreshDate = nil
    }

    // MARK: - Selection Management

    /// Select a queue by ID
    /// - Parameter id: The queue ID to select (queue name)
    public func selectQueue(id: String?) {
        selectedQueueId = id
    }

    /// Select a queue by index in the filtered list
    /// - Parameter index: Index in the filtered queues array
    public func selectQueue(at index: Int) {
        let filtered = filteredQueues
        guard index >= 0 && index < filtered.count else { return }
        selectedQueueId = filtered[index].id
    }

    /// Select the next queue in the filtered list
    public func selectNextQueue() {
        let filtered = filteredQueues
        guard !filtered.isEmpty else { return }

        if let currentId = selectedQueueId,
           let currentIndex = filtered.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % filtered.count
            selectedQueueId = filtered[nextIndex].id
        } else {
            selectedQueueId = filtered.first?.id
        }
    }

    /// Select the previous queue in the filtered list
    public func selectPreviousQueue() {
        let filtered = filteredQueues
        guard !filtered.isEmpty else { return }

        if let currentId = selectedQueueId,
           let currentIndex = filtered.firstIndex(where: { $0.id == currentId }) {
            let previousIndex = currentIndex == 0 ? filtered.count - 1 : currentIndex - 1
            selectedQueueId = filtered[previousIndex].id
        } else {
            selectedQueueId = filtered.last?.id
        }
    }

    /// Select the first queue in the filtered list
    public func selectFirstQueue() {
        selectedQueueId = filteredQueues.first?.id
    }

    /// Select the last queue in the filtered list
    public func selectLastQueue() {
        selectedQueueId = filteredQueues.last?.id
    }

    // MARK: - Filtering

    /// Get queues of a specific type
    /// - Parameter type: The queue type to filter by
    /// - Returns: Filtered array of queues
    public func queues(ofType type: MQQueueType) -> [Queue] {
        filteredQueues.filter { $0.queueType == type }
    }

    /// Get queues with messages
    /// - Returns: Array of queues that have messages
    public func queuesWithMessages() -> [Queue] {
        filteredQueues.filter { $0.hasMessages }
    }

    /// Get queues at or near capacity
    /// - Returns: Array of queues at warning/critical levels
    public func queuesNearCapacity() -> [Queue] {
        filteredQueues.filter { $0.isNearCapacity || $0.isCriticalCapacity || $0.isFull }
    }

    /// Toggle showing system queues
    public func toggleSystemQueues() {
        showSystemQueues.toggle()
    }

    /// Clear the search filter
    public func clearSearch() {
        searchText = ""
    }

    // MARK: - Sorting

    /// Apply the current sort order to an array of queues
    /// - Parameter queues: Queues to sort
    /// - Returns: Sorted array of queues
    private func sortQueues(_ queues: [Queue]) -> [Queue] {
        switch sortOrder {
        case .name:
            return queues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return queues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .depth:
            return queues.sorted { $0.depth > $1.depth }
        case .depthAscending:
            return queues.sorted { $0.depth < $1.depth }
        case .type:
            return queues.sorted { $0.queueType.rawValue < $1.queueType.rawValue }
        case .capacity:
            return queues.sorted { $0.depthPercentage > $1.depthPercentage }
        }
    }

    /// Cycle to the next sort order
    public func cycleSortOrder() {
        sortOrder = sortOrder.next
    }

    // MARK: - Error Handling

    /// Clear the last error
    public func clearError() {
        lastError = nil
        showErrorAlert = false
    }
}

// MARK: - QueueSortOrder

/// Sort order options for the queue list
public enum QueueSortOrder: String, CaseIterable, Identifiable {
    case name = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case depth = "Depth (High-Low)"
    case depthAscending = "Depth (Low-High)"
    case type = "Type"
    case capacity = "Capacity"

    public var id: String { rawValue }

    /// Display name for the sort order
    public var displayName: String { rawValue }

    /// SF Symbol for the sort order
    public var systemImageName: String {
        switch self {
        case .name, .nameDescending:
            return "textformat.abc"
        case .depth, .depthAscending:
            return "number"
        case .type:
            return "square.grid.2x2"
        case .capacity:
            return "chart.bar.fill"
        }
    }

    /// Get the next sort order in the cycle
    public var next: QueueSortOrder {
        let allCases = QueueSortOrder.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return .name
        }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - Preview Support

extension QueueViewModel {

    /// Create a QueueViewModel with sample data for SwiftUI previews
    public static var preview: QueueViewModel {
        let viewModel = QueueViewModel(mqService: PreviewMQService())
        viewModel.queues = Queue.samples
        viewModel.lastRefreshDate = Date()
        viewModel.selectedQueueId = Queue.samples.first?.id
        return viewModel
    }

    /// Create a QueueViewModel in loading state for SwiftUI previews
    public static var previewLoading: QueueViewModel {
        let viewModel = QueueViewModel(mqService: PreviewMQService())
        viewModel.queues = []
        // Note: isLoading is set via private setter, so we use a different approach
        // For true loading state preview, use the @Observable in the view
        return viewModel
    }

    /// Create an empty QueueViewModel for SwiftUI previews
    public static var previewEmpty: QueueViewModel {
        let viewModel = QueueViewModel(mqService: PreviewMQService())
        viewModel.queues = []
        return viewModel
    }

    /// Create a QueueViewModel with error state for SwiftUI previews
    public static var previewWithError: QueueViewModel {
        let viewModel = QueueViewModel(mqService: PreviewMQService())
        viewModel.lastError = MQError.notConnected
        viewModel.showErrorAlert = true
        return viewModel
    }
}

// MARK: - PreviewMQService

/// Mock MQ service for preview and testing purposes
@MainActor
private final class PreviewMQService: MQServiceProtocol {

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

    func deleteQueue(queueName: String) async throws {
        // Mock implementation - does nothing
    }

    func purgeQueue(queueName: String) async throws -> Int {
        // Mock implementation - return 0 messages purged
        return 0
    }

    func sendMessage(
        queueName: String,
        payload: Data,
        correlationId: [UInt8]?,
        replyToQueue: String?,
        messageType: MQService.MQMessageType,
        persistence: MQService.MQMessagePersistence,
        priority: Int32?
    ) async throws -> [UInt8] {
        // Mock implementation - return a fake message ID
        var messageId = [UInt8](repeating: 0, count: 24)
        for i in 0..<24 {
            messageId[i] = UInt8.random(in: 0...255)
        }
        return messageId
    }

    func deleteMessage(queueName: String, messageId: [UInt8]) async throws {
        // Mock implementation - does nothing
    }
}
