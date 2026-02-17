import Foundation

// MARK: - Message Type

/// Message type indicating the purpose of the message
public enum MessageType: Int32, Sendable, Equatable, Hashable, CaseIterable {
    case datagram = 8
    case request = 1
    case reply = 2
    case report = 4
    case unknown = -1

    public init(rawValue: Int32) {
        switch rawValue {
        case 8: self = .datagram
        case 1: self = .request
        case 2: self = .reply
        case 4: self = .report
        default: self = .unknown
        }
    }

    /// Human-readable display name for the message type
    public var displayName: String {
        switch self {
        case .datagram: return "Datagram"
        case .request: return "Request"
        case .reply: return "Reply"
        case .report: return "Report"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol name for the message type
    public var systemImageName: String {
        switch self {
        case .datagram: return "envelope"
        case .request: return "arrow.right.circle"
        case .reply: return "arrow.left.circle"
        case .report: return "flag"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Message Persistence

/// Message persistence indicating whether the message survives queue manager restarts
public enum MessagePersistence: Int32, Sendable, Equatable, Hashable, CaseIterable {
    case notPersistent = 0
    case persistent = 1
    case asQueueDef = 2
    case unknown = -1

    public init(rawValue: Int32) {
        switch rawValue {
        case 0: self = .notPersistent
        case 1: self = .persistent
        case 2: self = .asQueueDef
        default: self = .unknown
        }
    }

    /// Human-readable display name for the persistence type
    public var displayName: String {
        switch self {
        case .notPersistent: return "Not Persistent"
        case .persistent: return "Persistent"
        case .asQueueDef: return "As Queue Definition"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol name for the persistence type
    public var systemImageName: String {
        switch self {
        case .notPersistent: return "icloud.slash"
        case .persistent: return "externaldrive.fill"
        case .asQueueDef: return "gearshape"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Message Format

/// Well-known message formats in IBM MQ
public enum MessageFormat: String, Sendable, Equatable, Hashable, CaseIterable {
    case string = "MQSTR"
    case rf2Header = "MQHRF2"
    case rfHeader = "MQHRF"
    case cicsHeader = "MQCIH"
    case imsHeader = "MQIIH"
    case deadLetter = "MQDLH"
    case trigger = "MQTRIG"
    case pcf = "MQPCF"
    case adminMsg = "MQADMIN"
    case event = "MQEVENT"
    case none = "MQNONE"
    case unknown = ""

    /// Create from a format string (trimmed)
    public init(formatString: String) {
        let trimmed = formatString.trimmingCharacters(in: .whitespaces)
        self = MessageFormat(rawValue: trimmed) ?? .unknown
    }

    /// Human-readable display name for the format
    public var displayName: String {
        switch self {
        case .string: return "String"
        case .rf2Header: return "RFH2 Header"
        case .rfHeader: return "RFH Header"
        case .cicsHeader: return "CICS Header"
        case .imsHeader: return "IMS Header"
        case .deadLetter: return "Dead Letter Header"
        case .trigger: return "Trigger Message"
        case .pcf: return "PCF Message"
        case .adminMsg: return "Admin Message"
        case .event: return "Event Message"
        case .none: return "No Format"
        case .unknown: return "Unknown"
        }
    }

    /// Indicates if this format typically contains human-readable text
    public var isTextBased: Bool {
        switch self {
        case .string, .rf2Header, .rfHeader:
            return true
        default:
            return false
        }
    }
}

// MARK: - Message

/// Represents an IBM MQ message retrieved through browse operations
/// Contains message headers, metadata, and payload for display in the UI
public struct Message: Identifiable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier (hex-encoded message ID)
    public let id: String

    /// Raw message ID bytes (24 bytes)
    public let messageId: [UInt8]

    /// Correlation ID bytes (24 bytes)
    public let correlationId: [UInt8]

    /// Message format (e.g., "MQSTR", "MQHRF2")
    public let format: String

    /// Parsed message format enum
    public let messageFormat: MessageFormat

    /// Message payload as raw data
    public let payload: Data

    /// Timestamp when message was put to the queue
    public let putDateTime: Date?

    /// Name of the application that put the message
    public let putApplicationName: String

    /// Message type (request, reply, datagram, report)
    public let messageType: MessageType

    /// Message persistence level
    public let persistence: MessagePersistence

    /// Message priority (0-9, higher = more important)
    public let priority: Int32

    /// Reply-to queue name (for request/reply patterns)
    public let replyToQueue: String

    /// Reply-to queue manager name
    public let replyToQueueManager: String

    /// Message sequence number within a group
    public let messageSequenceNumber: Int32

    /// Position of this message in the queue (0-based index)
    public let position: Int

    // MARK: - Initialization

    /// Create a new Message instance with all properties
    /// - Parameters:
    ///   - messageId: Raw message ID bytes (24 bytes)
    ///   - correlationId: Correlation ID bytes (24 bytes)
    ///   - format: Message format string
    ///   - payload: Message payload data
    ///   - putDateTime: When the message was put to the queue
    ///   - putApplicationName: Application that put the message
    ///   - messageType: Type of message
    ///   - persistence: Persistence level
    ///   - priority: Message priority (0-9)
    ///   - replyToQueue: Reply-to queue name
    ///   - replyToQueueManager: Reply-to queue manager name
    ///   - messageSequenceNumber: Sequence number in group
    ///   - position: Position in queue
    public init(
        messageId: [UInt8],
        correlationId: [UInt8],
        format: String,
        payload: Data,
        putDateTime: Date?,
        putApplicationName: String,
        messageType: MessageType = .datagram,
        persistence: MessagePersistence = .notPersistent,
        priority: Int32 = 0,
        replyToQueue: String = "",
        replyToQueueManager: String = "",
        messageSequenceNumber: Int32 = 1,
        position: Int = 0
    ) {
        self.messageId = messageId
        self.correlationId = correlationId
        self.id = messageId.map { String(format: "%02X", $0) }.joined()
        self.format = format
        self.messageFormat = MessageFormat(formatString: format)
        self.payload = payload
        self.putDateTime = putDateTime
        self.putApplicationName = putApplicationName
        self.messageType = messageType
        self.persistence = persistence
        self.priority = priority
        self.replyToQueue = replyToQueue
        self.replyToQueueManager = replyToQueueManager
        self.messageSequenceNumber = messageSequenceNumber
        self.position = position
    }

    // MARK: - Computed Properties

    /// Message ID as a hex string
    public var messageIdHex: String {
        messageId.map { String(format: "%02X", $0) }.joined()
    }

    /// Message ID as a short hex string (first 8 bytes)
    public var messageIdShort: String {
        messageId.prefix(8).map { String(format: "%02X", $0) }.joined()
    }

    /// Correlation ID as a hex string
    public var correlationIdHex: String {
        correlationId.map { String(format: "%02X", $0) }.joined()
    }

    /// Correlation ID as a short hex string (first 8 bytes)
    public var correlationIdShort: String {
        correlationId.prefix(8).map { String(format: "%02X", $0) }.joined()
    }

    /// Check if correlation ID is set (non-zero)
    public var hasCorrelationId: Bool {
        !correlationId.allSatisfy { $0 == 0 }
    }

    /// Payload as a UTF-8 string (if decodable)
    public var payloadString: String? {
        String(data: payload, encoding: .utf8)
    }

    /// Payload size in bytes
    public var payloadSize: Int {
        payload.count
    }

    /// Formatted payload size for display (e.g., "1.2 KB")
    public var payloadSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(payload.count), countStyle: .file)
    }

    /// Check if payload appears to be binary (contains non-printable characters)
    public var isBinaryPayload: Bool {
        guard let string = payloadString else { return true }
        // Check if the string contains mostly printable characters
        let printableSet = CharacterSet.alphanumerics
            .union(.punctuationCharacters)
            .union(.whitespaces)
            .union(.newlines)
        let printableCount = string.unicodeScalars.filter { printableSet.contains($0) }.count
        return Double(printableCount) / Double(max(string.count, 1)) < 0.8
    }

    /// Payload as hex dump for binary content
    public var payloadHexDump: String {
        let bytesPerLine = 16
        var lines: [String] = []

        for offset in stride(from: 0, to: payload.count, by: bytesPerLine) {
            let lineBytes = payload[offset..<min(offset + bytesPerLine, payload.count)]

            // Hex part
            let hex = lineBytes.map { String(format: "%02X", $0) }.joined(separator: " ")

            // ASCII part
            let ascii = lineBytes.map { byte -> String in
                let char = Character(UnicodeScalar(byte))
                return char.isASCII && !char.isNewline && byte >= 32 && byte < 127
                    ? String(char)
                    : "."
            }.joined()

            // Offset + hex + padding + ASCII
            let padding = String(repeating: "   ", count: max(0, bytesPerLine - lineBytes.count))
            lines.append(String(format: "%08X  %@%@  |%@|", offset, hex, padding, ascii))
        }

        return lines.joined(separator: "\n")
    }

    /// Payload preview (first 100 characters or hex if binary)
    public var payloadPreview: String {
        if let string = payloadString, !isBinaryPayload {
            let preview = string.prefix(100)
            return preview.count < string.count ? "\(preview)..." : String(preview)
        } else {
            let hexPreview = payload.prefix(50).map { String(format: "%02X", $0) }.joined(separator: " ")
            return payload.count > 50 ? "\(hexPreview)..." : hexPreview
        }
    }

    /// Check if message has a reply-to queue
    public var hasReplyTo: Bool {
        !replyToQueue.isEmpty
    }

    /// Full reply-to destination (queue@queueManager)
    public var replyToDestination: String {
        if replyToQueueManager.isEmpty {
            return replyToQueue
        }
        return "\(replyToQueue)@\(replyToQueueManager)"
    }

    /// Put date/time formatted for display
    public var putDateTimeFormatted: String {
        guard let date = putDateTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Put date/time as relative time (e.g., "2 minutes ago")
    public var putDateTimeRelative: String {
        guard let date = putDateTime else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Priority formatted for display
    public var priorityDisplayString: String {
        switch priority {
        case 0: return "0 (Lowest)"
        case 1...3: return "\(priority) (Low)"
        case 4...6: return "\(priority) (Normal)"
        case 7...8: return "\(priority) (High)"
        case 9: return "9 (Highest)"
        default: return "\(priority)"
        }
    }

    // MARK: - Display Helpers

    /// SF Symbol name for the message type
    public var typeSystemImageName: String {
        messageType.systemImageName
    }

    /// SF Symbol name for persistence
    public var persistenceSystemImageName: String {
        persistence.systemImageName
    }

    /// Summary string for the message
    public var summary: String {
        var parts: [String] = []

        parts.append(messageType.displayName)
        parts.append(messageFormat.displayName)
        parts.append(payloadSizeFormatted)

        if persistence == .persistent {
            parts.append("Persistent")
        }

        return parts.joined(separator: " \u{2022} ")
    }

    /// Accessibility label for the message
    public var accessibilityLabel: String {
        var parts: [String] = [
            "\(messageType.displayName) message",
            "size \(payloadSizeFormatted)"
        ]

        if let date = putDateTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append("put at \(formatter.string(from: date))")
        }

        if persistence == .persistent {
            parts.append("persistent")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - CustomStringConvertible

extension Message: CustomStringConvertible {
    public var description: String {
        "Message(id=\(messageIdShort)..., type=\(messageType.displayName), format=\(format), size=\(payloadSize))"
    }
}

// MARK: - Comparable

extension Message: Comparable {
    /// Compare messages by position (arrival order)
    public static func < (lhs: Message, rhs: Message) -> Bool {
        lhs.position < rhs.position
    }
}

// MARK: - Sample Data for Previews

extension Message {
    /// Sample messages for SwiftUI previews and testing
    public static let samples: [Message] = [
        Message(
            messageId: [0x41, 0x4D, 0x51, 0x20, 0x51, 0x4D, 0x31, 0x20,
                       0x20, 0x20, 0x20, 0x20, 0x67, 0x89, 0xAB, 0xCD,
                       0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD],
            correlationId: Array(repeating: UInt8(0), count: 24),
            format: "MQSTR",
            payload: "Hello, World! This is a sample message payload for testing purposes.".data(using: .utf8)!,
            putDateTime: Date().addingTimeInterval(-120),
            putApplicationName: "SampleApp",
            messageType: .datagram,
            persistence: .notPersistent,
            priority: 5,
            replyToQueue: "",
            replyToQueueManager: "",
            messageSequenceNumber: 1,
            position: 0
        ),
        Message(
            messageId: [0x41, 0x4D, 0x51, 0x20, 0x51, 0x4D, 0x31, 0x20,
                       0x20, 0x20, 0x20, 0x20, 0x11, 0x22, 0x33, 0x44,
                       0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC],
            correlationId: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                           0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                           0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17],
            format: "MQHRF2",
            payload: """
            <mcd><Msd>jms_text</Msd></mcd>
            <jms><Dst>queue:///DEV.QUEUE.1</Dst></jms>
            This is a JMS message with RFH2 header.
            """.data(using: .utf8)!,
            putDateTime: Date().addingTimeInterval(-3600),
            putApplicationName: "JMSClient",
            messageType: .request,
            persistence: .persistent,
            priority: 7,
            replyToQueue: "DEV.REPLY.QUEUE",
            replyToQueueManager: "QM1",
            messageSequenceNumber: 1,
            position: 1
        ),
        Message(
            messageId: [0x41, 0x4D, 0x51, 0x20, 0x51, 0x4D, 0x31, 0x20,
                       0x20, 0x20, 0x20, 0x20, 0xDE, 0xAD, 0xBE, 0xEF,
                       0xCA, 0xFE, 0xBA, 0xBE, 0x12, 0x34, 0x56, 0x78],
            correlationId: Array(repeating: UInt8(0), count: 24),
            format: "MQNONE",
            payload: Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F]),
            putDateTime: Date().addingTimeInterval(-86400),
            putApplicationName: "BinaryProducer",
            messageType: .datagram,
            persistence: .persistent,
            priority: 0,
            replyToQueue: "",
            replyToQueueManager: "",
            messageSequenceNumber: 1,
            position: 2
        ),
        Message(
            messageId: [0x41, 0x4D, 0x51, 0x20, 0x51, 0x4D, 0x31, 0x20,
                       0x20, 0x20, 0x20, 0x20, 0xAA, 0xBB, 0xCC, 0xDD,
                       0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55],
            correlationId: Array(repeating: UInt8(0), count: 24),
            format: "MQSTR",
            payload: """
            {
                "orderId": "ORD-12345",
                "customerId": "CUST-67890",
                "items": [
                    {"sku": "ITEM-001", "quantity": 2, "price": 29.99},
                    {"sku": "ITEM-002", "quantity": 1, "price": 49.99}
                ],
                "total": 109.97,
                "status": "PENDING"
            }
            """.data(using: .utf8)!,
            putDateTime: Date().addingTimeInterval(-300),
            putApplicationName: "OrderService",
            messageType: .request,
            persistence: .persistent,
            priority: 9,
            replyToQueue: "ORDER.REPLY.QUEUE",
            replyToQueueManager: "QM1",
            messageSequenceNumber: 1,
            position: 3
        )
    ]

    /// Single sample message for SwiftUI previews
    public static let sample = samples[0]

    /// Sample text message
    public static let sampleText = samples[0]

    /// Sample JMS/RFH2 message
    public static let sampleRFH2 = samples[1]

    /// Sample binary message
    public static let sampleBinary = samples[2]

    /// Sample JSON message
    public static let sampleJSON = samples[3]
}
