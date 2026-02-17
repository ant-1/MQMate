import Foundation

// MARK: - AuditEntry

/// Represents a logged audit event for destructive operations
/// All destructive actions (delete, purge, create) are recorded for compliance and debugging
public struct AuditEntry: Identifiable, Codable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier for this audit entry
    public let id: UUID

    /// Timestamp when the action occurred
    public let timestamp: Date

    /// Type of action that was performed
    public let actionType: ActionType

    /// Name of the affected resource (queue name, message ID, etc.)
    public let resource: String

    /// Optional additional details about the action
    public let details: String?

    /// Name of the queue manager where the action occurred
    public let queueManager: String?

    /// Username that performed the action (if available)
    public let username: String?

    // MARK: - ActionType Enum

    /// Types of actions that are logged for audit purposes
    public enum ActionType: String, Codable, Sendable, CaseIterable {
        /// A message was deleted from a queue
        case messageDeleted = "message_deleted"

        /// All messages were purged from a queue
        case queuePurged = "queue_purged"

        /// A queue was deleted
        case queueDeleted = "queue_deleted"

        /// A new queue was created
        case queueCreated = "queue_created"

        /// A message was sent to a queue
        case messageSent = "message_sent"

        /// Human-readable description of the action
        public var displayName: String {
            switch self {
            case .messageDeleted:
                return "Message Deleted"
            case .queuePurged:
                return "Queue Purged"
            case .queueDeleted:
                return "Queue Deleted"
            case .queueCreated:
                return "Queue Created"
            case .messageSent:
                return "Message Sent"
            }
        }

        /// Icon name (SF Symbol) for the action type
        public var iconName: String {
            switch self {
            case .messageDeleted:
                return "trash"
            case .queuePurged:
                return "trash.fill"
            case .queueDeleted:
                return "xmark.bin"
            case .queueCreated:
                return "plus.rectangle"
            case .messageSent:
                return "paperplane"
            }
        }

        /// Whether this action is considered destructive
        public var isDestructive: Bool {
            switch self {
            case .messageDeleted, .queuePurged, .queueDeleted:
                return true
            case .queueCreated, .messageSent:
                return false
            }
        }
    }

    // MARK: - Initialization

    /// Create a new audit entry
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - timestamp: When the action occurred (defaults to now)
    ///   - actionType: The type of action performed
    ///   - resource: Name of the affected resource
    ///   - details: Optional additional details
    ///   - queueManager: Name of the queue manager
    ///   - username: Username that performed the action
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: ActionType,
        resource: String,
        details: String? = nil,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.resource = resource
        self.details = details
        self.queueManager = queueManager
        self.username = username
    }

    // MARK: - Display Helpers

    /// Formatted timestamp for display
    public var formattedTimestamp: String {
        Self.dateFormatter.string(from: timestamp)
    }

    /// Short formatted timestamp (time only)
    public var shortTimestamp: String {
        Self.timeFormatter.string(from: timestamp)
    }

    /// Summary description for list display
    public var summary: String {
        "\(actionType.displayName): \(resource)"
    }

    /// Detailed description for log output
    public var logDescription: String {
        var parts = [
            "[\(formattedTimestamp)]",
            actionType.displayName.uppercased(),
            "Resource: \(resource)"
        ]

        if let queueManager = queueManager {
            parts.append("QM: \(queueManager)")
        }

        if let username = username {
            parts.append("User: \(username)")
        }

        if let details = details {
            parts.append("Details: \(details)")
        }

        return parts.joined(separator: " | ")
    }

    // MARK: - Private Formatters

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Codable Extension

extension AuditEntry {
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case actionType
        case resource
        case details
        case queueManager
        case username
    }
}

// MARK: - CustomStringConvertible

extension AuditEntry: CustomStringConvertible {
    public var description: String {
        logDescription
    }
}

// MARK: - Sample Data for Previews

extension AuditEntry {
    /// Sample audit entries for SwiftUI previews and testing
    public static let samples: [AuditEntry] = [
        AuditEntry(
            actionType: .messageSent,
            resource: "DEV.QUEUE.1",
            details: "Sent test message with 256 bytes",
            queueManager: "DEV.QM1",
            username: "developer"
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-3600),
            actionType: .messageDeleted,
            resource: "DEV.QUEUE.1",
            details: "Message ID: 414D51204445562E514D31",
            queueManager: "DEV.QM1",
            username: "developer"
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-7200),
            actionType: .queuePurged,
            resource: "DEV.QUEUE.2",
            details: "Removed 15 messages",
            queueManager: "DEV.QM1",
            username: "admin"
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-86400),
            actionType: .queueCreated,
            resource: "DEV.QUEUE.NEW",
            details: "Type: Local Queue",
            queueManager: "DEV.QM1",
            username: "admin"
        ),
        AuditEntry(
            timestamp: Date().addingTimeInterval(-172800),
            actionType: .queueDeleted,
            resource: "DEV.QUEUE.OLD",
            details: "Queue was empty",
            queueManager: "DEV.QM1",
            username: "admin"
        )
    ]

    /// Single sample for SwiftUI previews
    public static let sample = samples[0]
}
