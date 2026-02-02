import Foundation

// MARK: - ConnectionConfig

/// Configuration for connecting to an IBM MQ queue manager
/// Stores all connection details except the password, which is stored securely in Keychain
public struct ConnectionConfig: Identifiable, Codable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier for this connection configuration
    public let id: UUID

    /// Display name for the connection (user-provided label)
    public var name: String

    /// Name of the queue manager to connect to
    public var queueManager: String

    /// Hostname or IP address of the queue manager
    public var hostname: String

    /// Port number for the connection (typically 1414)
    public var port: Int

    /// Server connection channel name
    public var channel: String

    /// Username for authentication (optional)
    /// Password is stored separately in Keychain using the connection ID as the key
    public var username: String?

    /// Date when this configuration was created
    public let createdAt: Date

    /// Date when this configuration was last modified
    public var modifiedAt: Date

    /// Date when this configuration was last used to connect
    public var lastConnectedAt: Date?

    // MARK: - Initialization

    /// Create a new connection configuration
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Display name for the connection
    ///   - queueManager: Name of the queue manager
    ///   - hostname: Hostname or IP address
    ///   - port: Port number (defaults to 1414)
    ///   - channel: Server connection channel name
    ///   - username: Optional username for authentication
    public init(
        id: UUID = UUID(),
        name: String,
        queueManager: String,
        hostname: String,
        port: Int = 1414,
        channel: String,
        username: String? = nil
    ) {
        self.id = id
        self.name = name
        self.queueManager = queueManager
        self.hostname = hostname
        self.port = port
        self.channel = channel
        self.username = username
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.lastConnectedAt = nil
    }

    // MARK: - Validation

    /// Validation result for connection configuration
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [ValidationError]

        public init(isValid: Bool, errors: [ValidationError]) {
            self.isValid = isValid
            self.errors = errors
        }

        public static let valid = ValidationResult(isValid: true, errors: [])
    }

    /// Types of validation errors
    public enum ValidationError: String, Sendable, CaseIterable {
        case nameEmpty = "Connection name cannot be empty"
        case queueManagerEmpty = "Queue manager name cannot be empty"
        case queueManagerTooLong = "Queue manager name cannot exceed 48 characters"
        case hostnameEmpty = "Hostname cannot be empty"
        case portInvalid = "Port must be between 1 and 65535"
        case channelEmpty = "Channel name cannot be empty"
        case channelTooLong = "Channel name cannot exceed 20 characters"

        public var localizedDescription: String {
            rawValue
        }
    }

    /// Validate the connection configuration
    /// - Returns: ValidationResult indicating if the configuration is valid
    public func validate() -> ValidationResult {
        var errors: [ValidationError] = []

        // Validate name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.nameEmpty)
        }

        // Validate queue manager name
        let trimmedQM = queueManager.trimmingCharacters(in: .whitespaces)
        if trimmedQM.isEmpty {
            errors.append(.queueManagerEmpty)
        } else if trimmedQM.count > 48 {
            errors.append(.queueManagerTooLong)
        }

        // Validate hostname
        if hostname.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.hostnameEmpty)
        }

        // Validate port
        if port < 1 || port > 65535 {
            errors.append(.portInvalid)
        }

        // Validate channel
        let trimmedChannel = channel.trimmingCharacters(in: .whitespaces)
        if trimmedChannel.isEmpty {
            errors.append(.channelEmpty)
        } else if trimmedChannel.count > 20 {
            errors.append(.channelTooLong)
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    /// Check if this configuration is valid
    public var isValid: Bool {
        validate().isValid
    }

    // MARK: - Keychain Key

    /// Key used to store/retrieve password in Keychain
    /// Uses the connection ID to uniquely identify the credential
    public var keychainKey: String {
        "mqmate.connection.\(id.uuidString)"
    }

    // MARK: - Display Helpers

    /// Connection string for display (hostname:port)
    public var connectionString: String {
        "\(hostname):\(port)"
    }

    /// Full connection description for display
    public var fullDescription: String {
        "\(queueManager) via \(channel) at \(connectionString)"
    }

    /// Short description for list display
    public var shortDescription: String {
        "\(hostname):\(port) / \(channel)"
    }

    // MARK: - Mutation Helpers

    /// Create a copy of this configuration with updated modification date
    public func withUpdatedModificationDate() -> ConnectionConfig {
        var copy = self
        copy.modifiedAt = Date()
        return copy
    }

    /// Create a copy of this configuration with updated last connected date
    public func withUpdatedLastConnectedDate() -> ConnectionConfig {
        var copy = self
        copy.lastConnectedAt = Date()
        copy.modifiedAt = Date()
        return copy
    }

    /// Create a copy of this configuration with a new ID (for duplicating)
    public func duplicate(withName newName: String? = nil) -> ConnectionConfig {
        ConnectionConfig(
            id: UUID(),
            name: newName ?? "\(name) (Copy)",
            queueManager: queueManager,
            hostname: hostname,
            port: port,
            channel: channel,
            username: username
        )
    }
}

// MARK: - Codable Extension

extension ConnectionConfig {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case queueManager
        case hostname
        case port
        case channel
        case username
        case createdAt
        case modifiedAt
        case lastConnectedAt
    }
}

// MARK: - CustomStringConvertible

extension ConnectionConfig: CustomStringConvertible {
    public var description: String {
        "ConnectionConfig(\(name): \(fullDescription))"
    }
}

// MARK: - Sample Data for Previews

extension ConnectionConfig {
    /// Sample connection configurations for SwiftUI previews and testing
    public static let samples: [ConnectionConfig] = [
        ConnectionConfig(
            name: "Development QM",
            queueManager: "DEV.QM1",
            hostname: "localhost",
            port: 1414,
            channel: "DEV.APP.SVRCONN",
            username: "app"
        ),
        ConnectionConfig(
            name: "Staging QM",
            queueManager: "STG.QM1",
            hostname: "staging.example.com",
            port: 1414,
            channel: "STG.APP.SVRCONN",
            username: "stagingapp"
        ),
        ConnectionConfig(
            name: "Production QM",
            queueManager: "PRD.QM1",
            hostname: "prod-mq.example.com",
            port: 1415,
            channel: "PRD.APP.SVRCONN",
            username: "prodapp"
        )
    ]

    /// Single sample for SwiftUI previews
    public static let sample = samples[0]

    /// Empty configuration for new connection forms
    public static let empty = ConnectionConfig(
        name: "",
        queueManager: "",
        hostname: "",
        port: 1414,
        channel: "",
        username: nil
    )
}
