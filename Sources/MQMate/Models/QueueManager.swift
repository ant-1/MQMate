import Foundation

// MARK: - QueueManager

/// Represents a connected or connecting queue manager with its current state
/// This model tracks the connection lifecycle and holds references to queues
public struct QueueManager: Identifiable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier derived from the connection configuration
    public var id: UUID {
        config.id
    }

    /// The connection configuration for this queue manager
    public let config: ConnectionConfig

    /// Current connection state
    public private(set) var connectionState: ConnectionState

    /// List of queues discovered on this queue manager
    public private(set) var queues: [Queue]

    /// Timestamp when the queue list was last refreshed
    public private(set) var lastRefreshedAt: Date?

    /// Error message if the last operation failed
    public private(set) var lastError: String?

    // MARK: - Connection State

    /// Represents the connection lifecycle states
    public enum ConnectionState: String, Sendable, Equatable, Hashable, CaseIterable {
        /// Not connected to the queue manager
        case disconnected
        /// Currently attempting to connect
        case connecting
        /// Successfully connected
        case connected
        /// Currently disconnecting
        case disconnecting
        /// Connection failed with an error
        case error

        /// Display name for the connection state
        public var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .disconnecting: return "Disconnecting..."
            case .error: return "Error"
            }
        }

        /// SF Symbol name for the connection state icon
        public var systemImageName: String {
            switch self {
            case .disconnected: return "bolt.slash.circle"
            case .connecting: return "bolt.circle"
            case .connected: return "bolt.circle.fill"
            case .disconnecting: return "bolt.circle"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        /// Color name for the connection state (use with Color(name))
        public var colorName: String {
            switch self {
            case .disconnected: return "secondary"
            case .connecting: return "orange"
            case .connected: return "green"
            case .disconnecting: return "orange"
            case .error: return "red"
            }
        }
    }

    // MARK: - Computed Properties

    /// Check if currently connected to the queue manager
    public var isConnected: Bool {
        connectionState == .connected
    }

    /// Check if currently in a transitional state (connecting or disconnecting)
    public var isTransitioning: Bool {
        connectionState == .connecting || connectionState == .disconnecting
    }

    /// Check if connection can be attempted
    public var canConnect: Bool {
        connectionState == .disconnected || connectionState == .error
    }

    /// Check if disconnection can be attempted
    public var canDisconnect: Bool {
        connectionState == .connected
    }

    /// Number of queues discovered
    public var queueCount: Int {
        queues.count
    }

    /// Total message count across all queues
    public var totalMessageCount: Int64 {
        queues.reduce(0) { $0 + Int64($1.depth) }
    }

    /// Display name for the queue manager (from config)
    public var displayName: String {
        config.name
    }

    /// Queue manager name from configuration
    public var queueManagerName: String {
        config.queueManager
    }

    /// Connection string for display
    public var connectionString: String {
        config.connectionString
    }

    // MARK: - Initialization

    /// Create a new QueueManager instance from a connection configuration
    /// - Parameter config: The connection configuration to use
    public init(config: ConnectionConfig) {
        self.config = config
        self.connectionState = .disconnected
        self.queues = []
        self.lastRefreshedAt = nil
        self.lastError = nil
    }

    /// Create a QueueManager with a specific initial state (for testing/previews)
    /// - Parameters:
    ///   - config: The connection configuration
    ///   - connectionState: Initial connection state
    ///   - queues: Initial queue list
    ///   - lastRefreshedAt: Initial refresh timestamp
    ///   - lastError: Initial error message
    public init(
        config: ConnectionConfig,
        connectionState: ConnectionState,
        queues: [Queue] = [],
        lastRefreshedAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.config = config
        self.connectionState = connectionState
        self.queues = queues
        self.lastRefreshedAt = lastRefreshedAt
        self.lastError = lastError
    }

    // MARK: - State Mutations

    /// Create a copy with updated connection state
    /// - Parameter state: The new connection state
    /// - Returns: A new QueueManager with the updated state
    public func withConnectionState(_ state: ConnectionState) -> QueueManager {
        var copy = self
        copy.connectionState = state
        if state == .connected {
            copy.lastError = nil
        }
        return copy
    }

    /// Create a copy with updated queues
    /// - Parameter queues: The new queue list
    /// - Returns: A new QueueManager with the updated queues
    public func withQueues(_ queues: [Queue]) -> QueueManager {
        var copy = self
        copy.queues = queues
        copy.lastRefreshedAt = Date()
        return copy
    }

    /// Create a copy with an error message
    /// - Parameter error: The error message
    /// - Returns: A new QueueManager with the error state
    public func withError(_ error: String) -> QueueManager {
        var copy = self
        copy.connectionState = .error
        copy.lastError = error
        return copy
    }

    /// Create a copy after successful connection
    /// - Returns: A new QueueManager in connected state
    public func connected() -> QueueManager {
        withConnectionState(.connected)
    }

    /// Create a copy after disconnection
    /// - Returns: A new QueueManager in disconnected state with cleared queues
    public func disconnected() -> QueueManager {
        var copy = withConnectionState(.disconnected)
        copy.queues = []
        copy.lastRefreshedAt = nil
        return copy
    }

    // MARK: - Queue Helpers

    /// Find a queue by name
    /// - Parameter name: The queue name to search for
    /// - Returns: The queue if found, nil otherwise
    public func queue(named name: String) -> Queue? {
        queues.first { $0.name == name }
    }

    /// Get queues filtered by type
    /// - Parameter type: The queue type to filter by
    /// - Returns: Array of queues matching the type
    public func queues(ofType type: MQQueueType) -> [Queue] {
        queues.filter { $0.queueType == type }
    }

    /// Get queues with messages (depth > 0)
    /// - Returns: Array of queues with at least one message
    public func queuesWithMessages() -> [Queue] {
        queues.filter { $0.depth > 0 }
    }

    /// Get local queues only
    public var localQueues: [Queue] {
        queues(ofType: .local)
    }

    /// Get alias queues only
    public var aliasQueues: [Queue] {
        queues(ofType: .alias)
    }

    /// Get remote queues only
    public var remoteQueues: [Queue] {
        queues(ofType: .remote)
    }

    // MARK: - Equatable & Hashable

    public static func == (lhs: QueueManager, rhs: QueueManager) -> Bool {
        lhs.id == rhs.id &&
        lhs.connectionState == rhs.connectionState &&
        lhs.queues == rhs.queues &&
        lhs.lastRefreshedAt == rhs.lastRefreshedAt &&
        lhs.lastError == rhs.lastError
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(connectionState)
        hasher.combine(queues)
        hasher.combine(lastRefreshedAt)
        hasher.combine(lastError)
    }
}

// MARK: - CustomStringConvertible

extension QueueManager: CustomStringConvertible {
    public var description: String {
        "QueueManager(\(displayName): \(connectionState.displayName), \(queueCount) queues)"
    }
}

// MARK: - Sample Data for Previews

extension QueueManager {
    /// Sample queue managers for SwiftUI previews and testing
    public static let samples: [QueueManager] = [
        QueueManager(
            config: ConnectionConfig.samples[0],
            connectionState: .connected,
            queues: Queue.samples,
            lastRefreshedAt: Date()
        ),
        QueueManager(
            config: ConnectionConfig.samples[1],
            connectionState: .disconnected
        ),
        QueueManager(
            config: ConnectionConfig.samples[2],
            connectionState: .error,
            lastError: "Connection refused: Host not available"
        )
    ]

    /// Single connected sample for SwiftUI previews
    public static let sampleConnected = samples[0]

    /// Single disconnected sample for SwiftUI previews
    public static let sampleDisconnected = samples[1]

    /// Single error sample for SwiftUI previews
    public static let sampleError = samples[2]
}

