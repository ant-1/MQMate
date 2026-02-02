import Foundation

// MARK: - IBM MQ Swift Type Aliases
// Swift-friendly type aliases for IBM MQ C library types
// These map to the underlying C types from cmqc.h

/// MQ Long integer type (maps to MQLONG in C)
public typealias MQLong = Int32

/// MQ Connection handle type (maps to MQHCONN in C)
public typealias MQConnectionHandle = Int32

/// MQ Object handle type (maps to MQHOBJ in C)
public typealias MQObjectHandle = Int32

/// MQ Character type (maps to MQCHAR in C)
public typealias MQChar = CChar

/// MQ Byte type (maps to MQBYTE in C)
public typealias MQByte = UInt8

// MARK: - Connection Handle Constants

/// Unusable connection handle - used to initialize connection handles
public let MQ_UNUSABLE_CONNECTION_HANDLE: MQConnectionHandle = 0

/// Default connection handle
public let MQ_DEFAULT_CONNECTION_HANDLE: MQConnectionHandle = 0

// MARK: - Object Handle Constants

/// Unusable object handle - used to initialize object handles
public let MQ_UNUSABLE_OBJECT_HANDLE: MQObjectHandle = 0

// MARK: - Completion Codes

/// MQ Completion Code enumeration
/// Maps to MQCC_* constants from cmqc.h
public enum MQCompletionCode: MQLong {
    /// Operation completed successfully
    case ok = 0
    /// Operation completed with warning
    case warning = 1
    /// Operation failed
    case failed = 2

    /// Check if the operation was successful (ok or warning)
    public var isSuccessful: Bool {
        return self == .ok || self == .warning
    }

    /// C constant value (MQCC_OK = 0, MQCC_WARNING = 1, MQCC_FAILED = 2)
    public static let MQCC_OK: MQLong = 0
    public static let MQCC_WARNING: MQLong = 1
    public static let MQCC_FAILED: MQLong = 2
}

// MARK: - Reason Codes

/// MQ Reason Code enumeration
/// Maps to MQRC_* constants from cmqc.h
/// Only includes commonly used reason codes
public enum MQReasonCode: MQLong {
    /// No reason to report
    case none = 0

    // Connection-related reason codes
    /// Connection broken (2009)
    case connectionBroken = 2009
    /// Not authorized (2035)
    case notAuthorized = 2035
    /// Queue manager not available (2059)
    case queueManagerNotAvailable = 2059
    /// Host not available (2538)
    case hostNotAvailable = 2538
    /// Channel not available (2537)
    case channelNotAvailable = 2537
    /// Connection quiescing (2202)
    case connectionQuiescing = 2202

    // Queue-related reason codes
    /// Unknown object name (2085)
    case unknownObjectName = 2085
    /// Object in use (2042)
    case objectInUse = 2042
    /// Object damaged (2101)
    case objectDamaged = 2101
    /// Queue full (2053)
    case queueFull = 2053
    /// Queue inhibited for put (2051)
    case putInhibited = 2051
    /// Queue inhibited for get (2016)
    case getInhibited = 2016

    // Message-related reason codes
    /// No message available (2033)
    case noMessageAvailable = 2033
    /// Message truncated (2080)
    case truncatedMessage = 2080
    /// Message too big for queue (2030)
    case messageTooBig = 2030
    /// Conversion failed (2119)
    case conversionFailed = 2119

    // Other common reason codes
    /// Invalid options (2046)
    case optionsError = 2046
    /// Buffer length error (2005)
    case bufferLengthError = 2005
    /// Handle not available (2017)
    case handleNotAvailable = 2017

    /// Unknown reason code
    case unknown = -1

    /// Create from raw MQLong value
    public init(rawValue: MQLong) {
        switch rawValue {
        case 0: self = .none
        case 2009: self = .connectionBroken
        case 2035: self = .notAuthorized
        case 2059: self = .queueManagerNotAvailable
        case 2538: self = .hostNotAvailable
        case 2537: self = .channelNotAvailable
        case 2202: self = .connectionQuiescing
        case 2085: self = .unknownObjectName
        case 2042: self = .objectInUse
        case 2101: self = .objectDamaged
        case 2053: self = .queueFull
        case 2051: self = .putInhibited
        case 2016: self = .getInhibited
        case 2033: self = .noMessageAvailable
        case 2080: self = .truncatedMessage
        case 2030: self = .messageTooBig
        case 2119: self = .conversionFailed
        case 2046: self = .optionsError
        case 2005: self = .bufferLengthError
        case 2017: self = .handleNotAvailable
        default: self = .unknown
        }
    }

    /// User-friendly description of the reason code
    public var localizedDescription: String {
        switch self {
        case .none:
            return "No error"
        case .connectionBroken:
            return "Connection to queue manager was broken"
        case .notAuthorized:
            return "Not authorized to access this resource"
        case .queueManagerNotAvailable:
            return "Queue manager is not available"
        case .hostNotAvailable:
            return "Host is not available"
        case .channelNotAvailable:
            return "Channel is not available"
        case .connectionQuiescing:
            return "Connection is quiescing"
        case .unknownObjectName:
            return "Unknown object name"
        case .objectInUse:
            return "Object is exclusively in use by another process"
        case .objectDamaged:
            return "Object is damaged"
        case .queueFull:
            return "Queue is full"
        case .putInhibited:
            return "Put operations are inhibited on this queue"
        case .getInhibited:
            return "Get operations are inhibited on this queue"
        case .noMessageAvailable:
            return "No message available"
        case .truncatedMessage:
            return "Message was truncated"
        case .messageTooBig:
            return "Message is too big for the queue"
        case .conversionFailed:
            return "Data conversion failed"
        case .optionsError:
            return "Options are not valid"
        case .bufferLengthError:
            return "Buffer length is not valid"
        case .handleNotAvailable:
            return "Handle is not available"
        case .unknown:
            return "Unknown error occurred"
        }
    }

    // C constant values for direct comparison
    public static let MQRC_NONE: MQLong = 0
    public static let MQRC_CONNECTION_BROKEN: MQLong = 2009
    public static let MQRC_NOT_AUTHORIZED: MQLong = 2035
    public static let MQRC_Q_MGR_NOT_AVAILABLE: MQLong = 2059
    public static let MQRC_HOST_NOT_AVAILABLE: MQLong = 2538
    public static let MQRC_CHANNEL_NOT_AVAILABLE: MQLong = 2537
    public static let MQRC_UNKNOWN_OBJECT_NAME: MQLong = 2085
    public static let MQRC_OBJECT_IN_USE: MQLong = 2042
    public static let MQRC_Q_FULL: MQLong = 2053
    public static let MQRC_NO_MSG_AVAILABLE: MQLong = 2033
    public static let MQRC_TRUNCATED_MSG_FAILED: MQLong = 2080
}

// MARK: - Queue Types

/// MQ Queue Type enumeration
/// Maps to MQQT_* constants from cmqc.h
public enum MQQueueType: MQLong {
    /// Local queue
    case local = 1
    /// Alias queue
    case alias = 3
    /// Remote queue
    case remote = 6
    /// Model queue
    case model = 7
    /// Cluster queue
    case cluster = 8

    /// Unknown queue type
    case unknown = -1

    /// Create from raw MQLong value
    public init(rawValue: MQLong) {
        switch rawValue {
        case 1: self = .local
        case 3: self = .alias
        case 6: self = .remote
        case 7: self = .model
        case 8: self = .cluster
        default: self = .unknown
        }
    }

    /// Display name for the queue type
    public var displayName: String {
        switch self {
        case .local: return "Local"
        case .alias: return "Alias"
        case .remote: return "Remote"
        case .model: return "Model"
        case .cluster: return "Cluster"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol name for the queue type icon
    public var systemImageName: String {
        switch self {
        case .local: return "tray.fill"
        case .alias: return "link"
        case .remote: return "network"
        case .model: return "doc.badge.gearshape"
        case .cluster: return "circle.grid.3x3.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    // C constant values
    public static let MQQT_LOCAL: MQLong = 1
    public static let MQQT_ALIAS: MQLong = 3
    public static let MQQT_REMOTE: MQLong = 6
    public static let MQQT_MODEL: MQLong = 7
    public static let MQQT_CLUSTER: MQLong = 8
}

// MARK: - Open Options

/// MQ Open Options
/// Maps to MQOO_* constants from cmqc.h
public struct MQOpenOptions: OptionSet {
    public let rawValue: MQLong

    public init(rawValue: MQLong) {
        self.rawValue = rawValue
    }

    /// Open to inquire attributes
    public static let inquire = MQOpenOptions(rawValue: 1)
    /// Open for browsing messages
    public static let browse = MQOpenOptions(rawValue: 8)
    /// Open for getting messages
    public static let inputShared = MQOpenOptions(rawValue: 2)
    /// Open for exclusive get
    public static let inputExclusive = MQOpenOptions(rawValue: 4)
    /// Open for putting messages
    public static let output = MQOpenOptions(rawValue: 16)
    /// Open to set attributes
    public static let setAttributes = MQOpenOptions(rawValue: 32)
    /// Fail if quiescing
    public static let failIfQuiescing = MQOpenOptions(rawValue: 8192)

    // C constant values
    public static let MQOO_INQUIRE: MQLong = 1
    public static let MQOO_BROWSE: MQLong = 8
    public static let MQOO_INPUT_SHARED: MQLong = 2
    public static let MQOO_INPUT_EXCLUSIVE: MQLong = 4
    public static let MQOO_OUTPUT: MQLong = 16
    public static let MQOO_SET: MQLong = 32
    public static let MQOO_FAIL_IF_QUIESCING: MQLong = 8192
}

// MARK: - Get Message Options

/// MQ Get Message Options
/// Maps to MQGMO_* constants from cmqc.h
public struct MQGetMessageOptions: OptionSet {
    public let rawValue: MQLong

    public init(rawValue: MQLong) {
        self.rawValue = rawValue
    }

    /// No wait for messages
    public static let noWait = MQGetMessageOptions(rawValue: 0)
    /// Wait for message
    public static let wait = MQGetMessageOptions(rawValue: 1)
    /// Browse first message
    public static let browseFirst = MQGetMessageOptions(rawValue: 16)
    /// Browse next message
    public static let browseNext = MQGetMessageOptions(rawValue: 32)
    /// Accept truncated message
    public static let acceptTruncatedMessage = MQGetMessageOptions(rawValue: 64)
    /// Convert message data
    public static let convert = MQGetMessageOptions(rawValue: 16384)
    /// Fail if quiescing
    public static let failIfQuiescing = MQGetMessageOptions(rawValue: 8192)

    // C constant values
    public static let MQGMO_NO_WAIT: MQLong = 0
    public static let MQGMO_WAIT: MQLong = 1
    public static let MQGMO_BROWSE_FIRST: MQLong = 16
    public static let MQGMO_BROWSE_NEXT: MQLong = 32
    public static let MQGMO_ACCEPT_TRUNCATED_MSG: MQLong = 64
    public static let MQGMO_CONVERT: MQLong = 16384
    public static let MQGMO_FAIL_IF_QUIESCING: MQLong = 8192
}

// MARK: - Connection Options

/// MQ Connection Options
/// Maps to MQCNO_* constants from cmqc.h
public struct MQConnectOptions: OptionSet {
    public let rawValue: MQLong

    public init(rawValue: MQLong) {
        self.rawValue = rawValue
    }

    /// Standard binding
    public static let standardBinding = MQConnectOptions(rawValue: 0)
    /// Handle sharing (for multi-threaded use)
    public static let handleShareBlock = MQConnectOptions(rawValue: 32)
    /// Handle sharing non-blocking
    public static let handleShareNoBlock = MQConnectOptions(rawValue: 64)

    // C constant values
    public static let MQCNO_STANDARD_BINDING: MQLong = 0
    public static let MQCNO_HANDLE_SHARE_BLOCK: MQLong = 32
    public static let MQCNO_HANDLE_SHARE_NO_BLOCK: MQLong = 64
}

// MARK: - Message Format Constants

/// Common MQ Message format strings
public enum MQMessageFormat {
    /// No format specified
    public static let none = "        "
    /// String format
    public static let string = "MQSTR   "
    /// Dead letter header
    public static let deadLetterHeader = "MQDEAD  "
    /// Event message
    public static let event = "MQEVENT "
    /// PCF format
    public static let pcf = "MQADMIN "
}

// MARK: - Attribute Selectors

/// MQ Attribute Selectors for MQINQ
/// Maps to MQIA_* and MQCA_* constants from cmqc.h
public enum MQAttributeSelector: MQLong {
    // Integer attributes (MQIA_*)
    /// Current queue depth
    case currentDepth = 3
    /// Maximum queue depth
    case maxDepth = 15
    /// Queue type
    case queueType = 20
    /// Inhibit get
    case inhibitGet = 9
    /// Inhibit put
    case inhibitPut = 10
    /// Open input count
    case openInputCount = 17
    /// Open output count
    case openOutputCount = 18

    // C constant values
    public static let MQIA_CURRENT_Q_DEPTH: MQLong = 3
    public static let MQIA_MAX_Q_DEPTH: MQLong = 15
    public static let MQIA_Q_TYPE: MQLong = 20
    public static let MQIA_INHIBIT_GET: MQLong = 9
    public static let MQIA_INHIBIT_PUT: MQLong = 10
    public static let MQIA_OPEN_INPUT_COUNT: MQLong = 17
    public static let MQIA_OPEN_OUTPUT_COUNT: MQLong = 18

    // Character attribute lengths
    public static let MQ_Q_NAME_LENGTH: Int = 48
    public static let MQ_Q_MGR_NAME_LENGTH: Int = 48
    public static let MQ_CHANNEL_NAME_LENGTH: Int = 20
    public static let MQ_CONN_NAME_LENGTH: Int = 264
}

// MARK: - Message ID and Correlation ID

/// MQ Message ID length (24 bytes)
public let MQ_MSG_ID_LENGTH: Int = 24

/// MQ Correlation ID length (24 bytes)
public let MQ_CORREL_ID_LENGTH: Int = 24

/// MQ Group ID length (24 bytes)
public let MQ_GROUP_ID_LENGTH: Int = 24

// MARK: - Wait Interval Constants

/// Wait interval for immediate return (no wait)
public let MQ_WAIT_INTERVAL_NONE: MQLong = 0

/// Wait interval for unlimited wait
public let MQ_WAIT_INTERVAL_UNLIMITED: MQLong = -1

/// Default wait interval (5 seconds)
public let MQ_WAIT_INTERVAL_DEFAULT: MQLong = 5000

// MARK: - Character Encoding

/// Default CCSID (coded character set identifier) for string conversion
public let MQ_CCSID_DEFAULT: MQLong = 0

/// UTF-8 CCSID
public let MQ_CCSID_UTF8: MQLong = 1208

// MARK: - Helper Extensions

extension String {
    /// Convert Swift String to MQ fixed-length character array (padded with spaces)
    /// - Parameter length: The fixed length for the MQ character field
    /// - Returns: Array of MQChar (CChar) with space padding
    public func toMQCharArray(length: Int) -> [MQChar] {
        var chars = Array<MQChar>(repeating: 0x20, count: length) // Space-padded
        let utf8 = self.utf8
        let copyLength = min(utf8.count, length)
        for (index, char) in utf8.prefix(copyLength).enumerated() {
            chars[index] = MQChar(bitPattern: char)
        }
        return chars
    }
}

extension Array where Element == MQChar {
    /// Convert MQ fixed-length character array to Swift String (trimming trailing spaces)
    public func toMQString() -> String {
        let data = self.map { UInt8(bitPattern: $0) }
        guard let string = String(bytes: data, encoding: .utf8) else {
            return ""
        }
        return string.trimmingCharacters(in: .whitespaces)
    }
}

extension Array where Element == MQByte {
    /// Convert MQ byte array to hex string for display
    public func toHexString() -> String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
