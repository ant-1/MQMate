import Foundation
import SwiftUI

// MARK: - ConnectionManager

/// ViewModel for managing IBM MQ queue manager connections
/// Handles connection lifecycle, credential storage, and connection state management
@Observable
@MainActor
public final class ConnectionManager {

    // MARK: - Properties

    /// All saved connection configurations
    public private(set) var savedConnections: [ConnectionConfig] = []

    /// Active QueueManager instances (one per connection)
    public private(set) var queueManagers: [UUID: QueueManager] = [:]

    /// Currently selected connection ID
    public var selectedConnectionId: UUID?

    /// Global loading state (for operations that affect multiple connections)
    public private(set) var isLoading: Bool = false

    /// Last error message for display
    public var lastError: Error?

    /// Show error alert flag
    public var showErrorAlert: Bool = false

    // MARK: - Dependencies

    /// MQ service for actual IBM MQ operations
    private let mqService: MQServiceProtocol

    /// Keychain service for credential storage
    private let keychainService: KeychainServiceProtocol

    /// User defaults key for saved connections
    private let savedConnectionsKey = "mqmate.savedConnections"

    // MARK: - Computed Properties

    /// Currently selected connection configuration
    public var selectedConnection: ConnectionConfig? {
        guard let id = selectedConnectionId else { return nil }
        return savedConnections.first { $0.id == id }
    }

    /// Currently selected queue manager
    public var selectedQueueManager: QueueManager? {
        guard let id = selectedConnectionId else { return nil }
        return queueManagers[id]
    }

    /// All queue managers sorted by display name
    public var connections: [QueueManager] {
        savedConnections.compactMap { config in
            queueManagers[config.id]
        }
    }

    /// Active (connected) queue managers
    public var activeConnections: [QueueManager] {
        connections.filter { $0.isConnected }
    }

    /// Check if any connection operation is in progress
    public var isConnecting: Bool {
        queueManagers.values.contains { $0.connectionState == .connecting }
    }

    /// Check if any connection is active
    public var hasActiveConnections: Bool {
        !activeConnections.isEmpty
    }

    // MARK: - Initialization

    /// Create a new ConnectionManager with dependencies
    /// - Parameters:
    ///   - mqService: MQ service for IBM MQ operations (defaults to new instance)
    ///   - keychainService: Keychain service for credentials (defaults to new instance)
    public init(
        mqService: MQServiceProtocol? = nil,
        keychainService: KeychainServiceProtocol? = nil
    ) {
        // Note: MQService is @MainActor, so we need to handle this carefully
        // For production, we'll create the service lazily or pass it in
        self.mqService = mqService ?? MQService()
        self.keychainService = keychainService ?? KeychainService()

        // Load saved connections
        loadSavedConnections()
    }

    // MARK: - Connection Management

    /// Connect to a queue manager
    /// - Parameter id: The connection configuration ID to connect
    /// - Throws: MQError if connection fails
    public func connect(id: UUID) async throws {
        guard let config = savedConnections.first(where: { $0.id == id }) else {
            throw MQError.invalidConfiguration(message: "Connection configuration not found")
        }

        // Get or create queue manager
        var queueManager = queueManagers[id] ?? QueueManager(config: config)

        // Check if already connected or connecting
        guard queueManager.canConnect else {
            return
        }

        // Update state to connecting
        queueManager = queueManager.withConnectionState(.connecting)
        queueManagers[id] = queueManager

        do {
            // Retrieve password from keychain
            let password = try keychainService.retrieve(for: config.keychainKey)

            // Perform connection
            try await mqService.connect(
                queueManager: config.queueManager,
                channel: config.channel,
                host: config.hostname,
                port: config.port,
                username: config.username,
                password: password
            )

            // Update to connected state
            queueManager = queueManager.connected()
            queueManagers[id] = queueManager

            // Update last connected timestamp
            updateConnectionLastUsed(id: id)

            // Load queues after connection
            try await refreshQueues(for: id)

        } catch {
            // Update to error state
            queueManager = queueManager.withError(error.localizedDescription)
            queueManagers[id] = queueManager

            lastError = error
            showErrorAlert = true
            throw error
        }
    }

    /// Disconnect from a queue manager
    /// - Parameter id: The connection configuration ID to disconnect
    public func disconnect(id: UUID) {
        guard var queueManager = queueManagers[id],
              queueManager.canDisconnect else {
            return
        }

        // Update state to disconnecting
        queueManager = queueManager.withConnectionState(.disconnecting)
        queueManagers[id] = queueManager

        // Perform disconnect
        mqService.disconnect()

        // Update to disconnected state
        queueManager = queueManager.disconnected()
        queueManagers[id] = queueManager
    }

    /// Disconnect from all connected queue managers
    public func disconnectAll() {
        for id in queueManagers.keys {
            if queueManagers[id]?.isConnected == true {
                disconnect(id: id)
            }
        }
    }

    /// Toggle connection state (connect if disconnected, disconnect if connected)
    /// - Parameter id: The connection configuration ID
    public func toggleConnection(id: UUID) async throws {
        guard let queueManager = queueManagers[id] else {
            // Create new queue manager and connect
            try await connect(id: id)
            return
        }

        if queueManager.isConnected {
            disconnect(id: id)
        } else if queueManager.canConnect {
            try await connect(id: id)
        }
    }

    /// Refresh queues for a connected queue manager
    /// - Parameter id: The connection configuration ID
    public func refreshQueues(for id: UUID) async throws {
        guard var queueManager = queueManagers[id],
              queueManager.isConnected else {
            return
        }

        let queues = try await mqService.listQueues(filter: "*")

        // Convert QueueInfo to Queue model
        let queueModels = queues.map { info in
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

        queueManager = queueManager.withQueues(queueModels)
        queueManagers[id] = queueManager
    }

    // MARK: - Connection Configuration Management

    /// Add a new connection configuration
    /// - Parameters:
    ///   - config: The connection configuration to add
    ///   - password: Optional password to store in keychain
    public func addConnection(_ config: ConnectionConfig, password: String? = nil) throws {
        // Validate configuration
        let validation = config.validate()
        guard validation.isValid else {
            let errorMessage = validation.errors.map { $0.localizedDescription }.joined(separator: ", ")
            throw MQError.invalidConfiguration(message: errorMessage)
        }

        // Check for duplicate
        guard !savedConnections.contains(where: { $0.id == config.id }) else {
            throw MQError.invalidConfiguration(message: "Connection with this ID already exists")
        }

        // Save password to keychain if provided
        if let password = password, !password.isEmpty {
            try keychainService.save(password: password, for: config.keychainKey)
        }

        // Add to saved connections
        savedConnections.append(config)

        // Create queue manager instance
        queueManagers[config.id] = QueueManager(config: config)

        // Persist changes
        saveSavedConnections()
    }

    /// Update an existing connection configuration
    /// - Parameters:
    ///   - config: The updated connection configuration
    ///   - password: Optional new password to store in keychain (nil to keep existing)
    public func updateConnection(_ config: ConnectionConfig, password: String? = nil) throws {
        // Validate configuration
        let validation = config.validate()
        guard validation.isValid else {
            let errorMessage = validation.errors.map { $0.localizedDescription }.joined(separator: ", ")
            throw MQError.invalidConfiguration(message: errorMessage)
        }

        // Find existing connection
        guard let index = savedConnections.firstIndex(where: { $0.id == config.id }) else {
            throw MQError.invalidConfiguration(message: "Connection not found")
        }

        // Disconnect if connected
        if queueManagers[config.id]?.isConnected == true {
            disconnect(id: config.id)
        }

        // Update password in keychain if provided
        if let password = password, !password.isEmpty {
            try keychainService.save(password: password, for: config.keychainKey)
        }

        // Update configuration
        let updatedConfig = config.withUpdatedModificationDate()
        savedConnections[index] = updatedConfig

        // Update queue manager with new config
        queueManagers[config.id] = QueueManager(config: updatedConfig)

        // Persist changes
        saveSavedConnections()
    }

    /// Delete a connection configuration
    /// - Parameter id: The connection configuration ID to delete
    public func deleteConnection(id: UUID) {
        guard let config = savedConnections.first(where: { $0.id == id }) else {
            return
        }

        // Disconnect if connected
        disconnect(id: id)

        // Delete password from keychain
        try? keychainService.delete(for: config.keychainKey)

        // Remove from saved connections
        savedConnections.removeAll { $0.id == id }

        // Remove queue manager instance
        queueManagers.removeValue(forKey: id)

        // Clear selection if this was selected
        if selectedConnectionId == id {
            selectedConnectionId = nil
        }

        // Persist changes
        saveSavedConnections()
    }

    /// Duplicate a connection configuration
    /// - Parameters:
    ///   - id: The connection configuration ID to duplicate
    ///   - newName: Optional new name for the duplicate
    /// - Returns: The duplicated connection configuration
    @discardableResult
    public func duplicateConnection(id: UUID, newName: String? = nil) throws -> ConnectionConfig {
        guard let config = savedConnections.first(where: { $0.id == id }) else {
            throw MQError.invalidConfiguration(message: "Connection not found")
        }

        let duplicate = config.duplicate(withName: newName)

        // Copy password from original to duplicate
        if let password = try? keychainService.retrieve(for: config.keychainKey) {
            try? keychainService.save(password: password, for: duplicate.keychainKey)
        }

        try addConnection(duplicate)

        return duplicate
    }

    /// Check if a password is stored for a connection
    /// - Parameter id: The connection configuration ID
    /// - Returns: True if a password is stored
    public func hasPassword(for id: UUID) -> Bool {
        guard let config = savedConnections.first(where: { $0.id == id }) else {
            return false
        }
        return keychainService.exists(for: config.keychainKey)
    }

    // MARK: - Selection Management

    /// Select a connection by ID
    /// - Parameter id: The connection configuration ID to select
    public func selectConnection(id: UUID?) {
        selectedConnectionId = id
    }

    /// Select the next connection in the list
    public func selectNextConnection() {
        guard let currentId = selectedConnectionId,
              let currentIndex = savedConnections.firstIndex(where: { $0.id == currentId }) else {
            selectedConnectionId = savedConnections.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % savedConnections.count
        selectedConnectionId = savedConnections[nextIndex].id
    }

    /// Select the previous connection in the list
    public func selectPreviousConnection() {
        guard let currentId = selectedConnectionId,
              let currentIndex = savedConnections.firstIndex(where: { $0.id == currentId }) else {
            selectedConnectionId = savedConnections.last?.id
            return
        }

        let previousIndex = currentIndex == 0 ? savedConnections.count - 1 : currentIndex - 1
        selectedConnectionId = savedConnections[previousIndex].id
    }

    // MARK: - Error Handling

    /// Clear the last error
    public func clearError() {
        lastError = nil
        showErrorAlert = false
    }

    // MARK: - Private Methods

    /// Update the last connected timestamp for a connection
    private func updateConnectionLastUsed(id: UUID) {
        guard let index = savedConnections.firstIndex(where: { $0.id == id }) else {
            return
        }

        let updatedConfig = savedConnections[index].withUpdatedLastConnectedDate()
        savedConnections[index] = updatedConfig
        saveSavedConnections()
    }

    /// Load saved connections from UserDefaults
    private func loadSavedConnections() {
        guard let data = UserDefaults.standard.data(forKey: savedConnectionsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedConnections = try decoder.decode([ConnectionConfig].self, from: data)

            // Create queue manager instances for each saved connection
            for config in savedConnections {
                queueManagers[config.id] = QueueManager(config: config)
            }
        } catch {
            // Failed to load connections - start fresh
            savedConnections = []
        }
    }

    /// Save connections to UserDefaults
    private func saveSavedConnections() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(savedConnections)
            UserDefaults.standard.set(data, forKey: savedConnectionsKey)
        } catch {
            // Failed to save - log error in production
        }
    }
}

// MARK: - Convenience Extensions

extension ConnectionManager {

    /// Get the connection state for a connection ID
    /// - Parameter id: The connection configuration ID
    /// - Returns: The connection state, or .disconnected if not found
    public func connectionState(for id: UUID) -> QueueManager.ConnectionState {
        queueManagers[id]?.connectionState ?? .disconnected
    }

    /// Check if a specific connection is connected
    /// - Parameter id: The connection configuration ID
    /// - Returns: True if connected
    public func isConnected(id: UUID) -> Bool {
        queueManagers[id]?.isConnected ?? false
    }

    /// Get the queues for a connection ID
    /// - Parameter id: The connection configuration ID
    /// - Returns: Array of queues, or empty if not connected
    public func queues(for id: UUID) -> [Queue] {
        queueManagers[id]?.queues ?? []
    }
}

// MARK: - Preview Support

extension ConnectionManager {

    /// Create a ConnectionManager with sample data for SwiftUI previews
    public static var preview: ConnectionManager {
        let manager = ConnectionManager(
            mqService: MockMQService(),
            keychainService: MockKeychainService()
        )

        // Add sample connections
        for config in ConnectionConfig.samples {
            try? manager.addConnection(config, password: "preview-password")
        }

        // Set up preview state
        if let firstConfig = ConnectionConfig.samples.first {
            manager.queueManagers[firstConfig.id] = QueueManager.sampleConnected
            manager.selectedConnectionId = firstConfig.id
        }

        return manager
    }
}

// MARK: - MockMQService for Previews

/// Mock MQ service for SwiftUI previews and testing
@MainActor
public final class MockMQService: MQServiceProtocol {

    public var isConnected: Bool = false
    public var shouldFailConnect: Bool = false
    public var simulatedQueues: [MQService.QueueInfo] = []

    public init() {
        // Set up default simulated queues
        simulatedQueues = [
            MQService.QueueInfo(name: "DEV.QUEUE.1", queueType: .local, currentDepth: 5, maxDepth: 5000),
            MQService.QueueInfo(name: "DEV.QUEUE.2", queueType: .local, currentDepth: 0, maxDepth: 5000),
            MQService.QueueInfo(name: "DEV.QUEUE.3", queueType: .local, currentDepth: 142, maxDepth: 5000)
        ]
    }

    public func connect(
        queueManager: String,
        channel: String,
        host: String,
        port: Int,
        username: String?,
        password: String?
    ) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        if shouldFailConnect {
            throw MQError.connectionFailed(reasonCode: 2538, queueManager: "MockQM")
        }

        isConnected = true
    }

    public func disconnect() {
        isConnected = false
    }

    public func getQueueInfo(queueName: String) throws -> MQService.QueueInfo {
        if let queue = simulatedQueues.first(where: { $0.name == queueName }) {
            return queue
        }
        throw MQError.operationFailed(operation: "MQOPEN", completionCode: 2, reasonCode: 2085)
    }

    public func listQueues(filter: String) async throws -> [MQService.QueueInfo] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        guard isConnected else {
            throw MQError.notConnected
        }

        return simulatedQueues
    }
}
