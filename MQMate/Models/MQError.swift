import Foundation

// MARK: - MQError

/// Comprehensive error type for IBM MQ operations in MQMate
/// Maps IBM MQ reason codes (MQRC_*) to user-friendly errors with actionable descriptions
public enum MQError: Error, LocalizedError, Equatable, Sendable {

    // MARK: - Connection Errors

    /// Connection to queue manager failed
    /// - Parameters:
    ///   - reasonCode: IBM MQ reason code (MQRC_*)
    ///   - queueManager: Name of the queue manager that failed to connect
    case connectionFailed(reasonCode: Int32, queueManager: String)

    /// Disconnection from queue manager failed
    /// - Parameter reasonCode: IBM MQ reason code (MQRC_*)
    case disconnectFailed(reasonCode: Int32)

    /// Not currently connected to any queue manager
    case notConnected

    /// Connection was broken unexpectedly (MQRC_CONNECTION_BROKEN = 2009)
    case connectionBroken

    /// Connection is quiescing/shutting down (MQRC_CONNECTION_QUIESCING = 2202)
    case connectionQuiescing

    // MARK: - Authentication Errors

    /// Not authorized to access the resource (MQRC_NOT_AUTHORIZED = 2035)
    /// - Parameter resource: The resource that access was denied to
    case notAuthorized(resource: String)

    /// Invalid or missing credentials
    case authenticationFailed(message: String)

    // MARK: - Network Errors

    /// Host is not available (MQRC_HOST_NOT_AVAILABLE = 2538)
    /// - Parameters:
    ///   - host: The hostname that could not be reached
    ///   - port: The port number
    case hostNotAvailable(host: String, port: Int)

    /// Channel is not available (MQRC_CHANNEL_NOT_AVAILABLE = 2537)
    /// - Parameter channel: The channel name
    case channelNotAvailable(channel: String)

    /// Queue manager is not available (MQRC_Q_MGR_NOT_AVAILABLE = 2059)
    /// - Parameter queueManager: Name of the queue manager
    case queueManagerNotAvailable(queueManager: String)

    /// Connection timeout occurred
    /// - Parameter timeout: Timeout value in seconds
    case connectionTimeout(timeout: TimeInterval)

    // MARK: - Queue Errors

    /// Unknown object/queue name (MQRC_UNKNOWN_OBJECT_NAME = 2085)
    /// - Parameter name: The object name that was not found
    case unknownObjectName(name: String)

    /// Object/queue is exclusively in use (MQRC_OBJECT_IN_USE = 2042)
    /// - Parameter name: The object name that is in use
    case objectInUse(name: String)

    /// Object is damaged (MQRC_OBJECT_DAMAGED = 2101)
    /// - Parameter name: The damaged object name
    case objectDamaged(name: String)

    /// Queue is full (MQRC_Q_FULL = 2053)
    /// - Parameter queueName: Name of the full queue
    case queueFull(queueName: String)

    /// Put operations are inhibited on the queue (MQRC_PUT_INHIBITED = 2051)
    /// - Parameter queueName: Name of the queue
    case putInhibited(queueName: String)

    /// Get operations are inhibited on the queue (MQRC_GET_INHIBITED = 2016)
    /// - Parameter queueName: Name of the queue
    case getInhibited(queueName: String)

    // MARK: - Message Errors

    /// No message available in the queue (MQRC_NO_MSG_AVAILABLE = 2033)
    case noMessageAvailable

    /// Message was truncated (MQRC_TRUNCATED_MSG_FAILED = 2080)
    /// - Parameter actualSize: The actual size of the message
    case messageTruncated(actualSize: Int)

    /// Message is too big for the queue (MQRC_MSG_TOO_BIG_FOR_Q = 2030)
    /// - Parameters:
    ///   - messageSize: Size of the message
    ///   - maxSize: Maximum allowed size
    case messageTooBig(messageSize: Int, maxSize: Int)

    /// Data conversion failed (MQRC_CONVERTED_MSG_TOO_BIG = 2120, MQRC_NOT_CONVERTED = 2119)
    case conversionFailed(message: String)

    // MARK: - Operation Errors

    /// Generic operation failure with MQ completion and reason codes
    /// - Parameters:
    ///   - operation: Name of the operation that failed
    ///   - completionCode: MQCC_* completion code
    ///   - reasonCode: MQRC_* reason code
    case operationFailed(operation: String, completionCode: Int32, reasonCode: Int32)

    /// Invalid options provided (MQRC_OPTIONS_ERROR = 2046)
    /// - Parameter message: Description of the invalid options
    case invalidOptions(message: String)

    /// Buffer length error (MQRC_BUFFER_LENGTH_ERROR = 2005)
    case bufferLengthError

    /// Handle not available (MQRC_HCONN_ERROR = 2018, MQRC_HOBJ_ERROR = 2019)
    case handleError(message: String)

    // MARK: - Configuration Errors

    /// Invalid configuration provided
    /// - Parameter message: Description of what's invalid
    case invalidConfiguration(message: String)

    // MARK: - Keychain Errors (for credential storage)

    /// Failed to save credentials to Keychain
    /// - Parameter status: OSStatus error code
    case keychainSaveFailed(status: Int32)

    /// Failed to retrieve credentials from Keychain
    /// - Parameter status: OSStatus error code
    case keychainRetrieveFailed(status: Int32)

    /// Failed to delete credentials from Keychain
    /// - Parameter status: OSStatus error code
    case keychainDeleteFailed(status: Int32)

    // MARK: - Unknown/Generic Errors

    /// Unknown error with raw reason code
    /// - Parameter reasonCode: The unrecognized MQRC_* code
    case unknown(reasonCode: Int32)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        // Connection errors
        case .connectionFailed(let reasonCode, let queueManager):
            return "Failed to connect to queue manager '\(queueManager)' (MQRC \(reasonCode)): \(Self.reasonCodeDescription(reasonCode))"

        case .disconnectFailed(let reasonCode):
            return "Failed to disconnect from queue manager (MQRC \(reasonCode)): \(Self.reasonCodeDescription(reasonCode))"

        case .notConnected:
            return "Not connected to a queue manager. Please connect first."

        case .connectionBroken:
            return "Connection to the queue manager was lost. The network connection may have been interrupted."

        case .connectionQuiescing:
            return "The queue manager is shutting down. Please try again later."

        // Authentication errors
        case .notAuthorized(let resource):
            return "Not authorized to access '\(resource)'. Check your credentials and permissions."

        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"

        // Network errors
        case .hostNotAvailable(let host, let port):
            return "Cannot reach host '\(host)' on port \(port). Check the hostname and ensure the network is accessible."

        case .channelNotAvailable(let channel):
            return "Channel '\(channel)' is not available. Verify the channel name and ensure the listener is running."

        case .queueManagerNotAvailable(let queueManager):
            return "Queue manager '\(queueManager)' is not available. It may be stopped or not configured for client connections."

        case .connectionTimeout(let timeout):
            return "Connection timed out after \(Int(timeout)) seconds. The queue manager may be overloaded or unreachable."

        // Queue errors
        case .unknownObjectName(let name):
            return "Object '\(name)' does not exist. Verify the name and queue manager."

        case .objectInUse(let name):
            return "Object '\(name)' is exclusively in use by another application."

        case .objectDamaged(let name):
            return "Object '\(name)' is damaged. Contact your MQ administrator."

        case .queueFull(let queueName):
            return "Queue '\(queueName)' is full. Wait for messages to be consumed or increase the queue depth limit."

        case .putInhibited(let queueName):
            return "Put operations are disabled on queue '\(queueName)'. The queue is set to inhibit puts."

        case .getInhibited(let queueName):
            return "Get operations are disabled on queue '\(queueName)'. The queue is set to inhibit gets."

        // Message errors
        case .noMessageAvailable:
            return "No messages available in the queue."

        case .messageTruncated(let actualSize):
            return "Message was truncated. The actual message size is \(actualSize) bytes."

        case .messageTooBig(let messageSize, let maxSize):
            return "Message size (\(messageSize) bytes) exceeds the maximum allowed size (\(maxSize) bytes)."

        case .conversionFailed(let message):
            return "Message data conversion failed: \(message)"

        // Operation errors
        case .operationFailed(let operation, let completionCode, let reasonCode):
            return "\(operation) failed (CC=\(completionCode), MQRC \(reasonCode)): \(Self.reasonCodeDescription(reasonCode))"

        case .invalidOptions(let message):
            return "Invalid options specified: \(message)"

        case .bufferLengthError:
            return "Buffer length error. The provided buffer is too small."

        case .handleError(let message):
            return "Handle error: \(message)"

        // Configuration errors
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"

        // Keychain errors
        case .keychainSaveFailed(let status):
            return "Failed to save credentials to Keychain (OSStatus \(status))"

        case .keychainRetrieveFailed(let status):
            return "Failed to retrieve credentials from Keychain (OSStatus \(status))"

        case .keychainDeleteFailed(let status):
            return "Failed to delete credentials from Keychain (OSStatus \(status))"

        // Unknown
        case .unknown(let reasonCode):
            return "Unknown MQ error (MQRC \(reasonCode)): \(Self.reasonCodeDescription(reasonCode))"
        }
    }

    /// Recovery suggestion for the error
    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Verify the connection parameters (host, port, channel, queue manager name) and ensure the queue manager is running."

        case .notConnected:
            return "Use the Connect action to establish a connection to a queue manager."

        case .connectionBroken:
            return "Try reconnecting to the queue manager."

        case .notAuthorized:
            return "Verify your username and password, and ensure you have the required permissions."

        case .hostNotAvailable:
            return "Check your network connection and verify the hostname and port are correct."

        case .channelNotAvailable:
            return "Ensure the MQ listener is running and the channel is defined correctly."

        case .queueManagerNotAvailable:
            return "Start the queue manager or verify it accepts client connections."

        case .connectionTimeout:
            return "Try again later or check network connectivity."

        case .unknownObjectName:
            return "Verify the object name is spelled correctly and exists in the queue manager."

        case .objectInUse:
            return "Wait for the other application to release the object, or use a shared access option."

        case .queueFull:
            return "Wait for consumers to process messages, or contact your administrator to increase the queue depth."

        case .putInhibited, .getInhibited:
            return "Contact your MQ administrator to enable operations on this queue."

        case .keychainSaveFailed, .keychainRetrieveFailed, .keychainDeleteFailed:
            return "Check Keychain access permissions in System Preferences."

        default:
            return nil
        }
    }

    // MARK: - Factory Methods

    /// Create an MQError from an IBM MQ reason code with context
    /// - Parameters:
    ///   - reasonCode: The MQRC_* reason code
    ///   - context: Additional context about the operation
    /// - Returns: An appropriate MQError case
    public static func from(reasonCode: Int32, context: String = "") -> MQError {
        switch reasonCode {
        // Connection-related
        case MQRC_CONNECTION_BROKEN:
            return .connectionBroken
        case MQRC_NOT_AUTHORIZED:
            return .notAuthorized(resource: context.isEmpty ? "resource" : context)
        case MQRC_Q_MGR_NOT_AVAILABLE:
            return .queueManagerNotAvailable(queueManager: context)
        case MQRC_HOST_NOT_AVAILABLE:
            return .hostNotAvailable(host: context, port: 1414)
        case MQRC_CHANNEL_NOT_AVAILABLE:
            return .channelNotAvailable(channel: context)
        case MQRC_CONNECTION_QUIESCING:
            return .connectionQuiescing

        // Queue-related
        case MQRC_UNKNOWN_OBJECT_NAME:
            return .unknownObjectName(name: context.isEmpty ? "unknown" : context)
        case MQRC_OBJECT_IN_USE:
            return .objectInUse(name: context.isEmpty ? "unknown" : context)
        case MQRC_OBJECT_DAMAGED:
            return .objectDamaged(name: context.isEmpty ? "unknown" : context)
        case MQRC_Q_FULL:
            return .queueFull(queueName: context.isEmpty ? "unknown" : context)
        case MQRC_PUT_INHIBITED:
            return .putInhibited(queueName: context.isEmpty ? "unknown" : context)
        case MQRC_GET_INHIBITED:
            return .getInhibited(queueName: context.isEmpty ? "unknown" : context)

        // Message-related
        case MQRC_NO_MSG_AVAILABLE:
            return .noMessageAvailable
        case MQRC_TRUNCATED_MSG_FAILED:
            return .messageTruncated(actualSize: 0)
        case MQRC_MSG_TOO_BIG_FOR_Q:
            return .messageTooBig(messageSize: 0, maxSize: 0)
        case MQRC_NOT_CONVERTED:
            return .conversionFailed(message: "Data conversion not performed")

        // Other
        case MQRC_OPTIONS_ERROR:
            return .invalidOptions(message: context)
        case MQRC_BUFFER_LENGTH_ERROR:
            return .bufferLengthError
        case MQRC_HCONN_ERROR, MQRC_HOBJ_ERROR:
            return .handleError(message: "Invalid handle")

        default:
            return .unknown(reasonCode: reasonCode)
        }
    }

    // MARK: - Reason Code Descriptions

    /// Get a human-readable description for an MQRC_* reason code
    /// - Parameter reasonCode: The IBM MQ reason code
    /// - Returns: A user-friendly description
    public static func reasonCodeDescription(_ reasonCode: Int32) -> String {
        switch reasonCode {
        case MQRC_NONE:
            return "No error"
        case MQRC_ALIAS_BASE_Q_TYPE_ERROR:
            return "Alias base queue type error"
        case MQRC_ALREADY_CONNECTED:
            return "Already connected to queue manager"
        case MQRC_BACKED_OUT:
            return "Unit of work was backed out"
        case MQRC_BUFFER_ERROR:
            return "Buffer parameter error"
        case MQRC_BUFFER_LENGTH_ERROR:
            return "Buffer length error"
        case MQRC_CHAR_ATTR_LENGTH_ERROR:
            return "Character attribute length error"
        case MQRC_CHAR_ATTRS_ERROR:
            return "Character attributes error"
        case MQRC_CHAR_ATTRS_TOO_SHORT:
            return "Character attributes buffer too short"
        case MQRC_CONNECTION_BROKEN:
            return "Connection to queue manager broken"
        case MQRC_DATA_LENGTH_ERROR:
            return "Data length error"
        case MQRC_DYNAMIC_Q_NAME_ERROR:
            return "Dynamic queue name error"
        case MQRC_ENVIRONMENT_ERROR:
            return "Environment error"
        case MQRC_EXPIRY_ERROR:
            return "Expiry value error"
        case MQRC_FEEDBACK_ERROR:
            return "Feedback code error"
        case MQRC_GET_INHIBITED:
            return "Get operations inhibited on queue"
        case MQRC_HANDLE_NOT_AVAILABLE:
            return "Handle not available"
        case MQRC_HCONN_ERROR:
            return "Connection handle error"
        case MQRC_HOBJ_ERROR:
            return "Object handle error"
        case MQRC_INHIBIT_VALUE_ERROR:
            return "Inhibit value error"
        case MQRC_INT_ATTR_COUNT_ERROR:
            return "Integer attribute count error"
        case MQRC_INT_ATTR_COUNT_TOO_SMALL:
            return "Integer attribute count too small"
        case MQRC_INT_ATTRS_ARRAY_ERROR:
            return "Integer attributes array error"
        case MQRC_SYNCPOINT_LIMIT_REACHED:
            return "Syncpoint limit reached"
        case MQRC_MAX_CONNS_LIMIT_REACHED:
            return "Maximum connections limit reached"
        case MQRC_MD_ERROR:
            return "Message descriptor error"
        case MQRC_MISSING_REPLY_TO_Q:
            return "Missing reply-to queue"
        case MQRC_MSG_TYPE_ERROR:
            return "Message type error"
        case MQRC_MSG_TOO_BIG_FOR_Q:
            return "Message too big for queue"
        case MQRC_MSG_TOO_BIG_FOR_Q_MGR:
            return "Message too big for queue manager"
        case MQRC_NO_MSG_AVAILABLE:
            return "No message available"
        case MQRC_NO_MSG_UNDER_CURSOR:
            return "No message under cursor"
        case MQRC_NOT_AUTHORIZED:
            return "Not authorized"
        case MQRC_NOT_OPEN_FOR_BROWSE:
            return "Queue not open for browse"
        case MQRC_NOT_OPEN_FOR_INPUT:
            return "Queue not open for input"
        case MQRC_NOT_OPEN_FOR_INQUIRE:
            return "Queue not open for inquire"
        case MQRC_NOT_OPEN_FOR_OUTPUT:
            return "Queue not open for output"
        case MQRC_NOT_OPEN_FOR_SET:
            return "Queue not open for set"
        case MQRC_OBJECT_CHANGED:
            return "Object definition changed since opened"
        case MQRC_OBJECT_IN_USE:
            return "Object in use"
        case MQRC_OBJECT_TYPE_ERROR:
            return "Object type error"
        case MQRC_OD_ERROR:
            return "Object descriptor error"
        case MQRC_OPTION_NOT_VALID_FOR_TYPE:
            return "Option not valid for object type"
        case MQRC_OPTIONS_ERROR:
            return "Options error"
        case MQRC_PERSISTENCE_ERROR:
            return "Persistence error"
        case MQRC_PERSISTENT_NOT_ALLOWED:
            return "Persistent messages not allowed"
        case MQRC_PRIORITY_EXCEEDS_MAXIMUM:
            return "Priority exceeds maximum"
        case MQRC_PRIORITY_ERROR:
            return "Priority error"
        case MQRC_PUT_INHIBITED:
            return "Put operations inhibited on queue"
        case MQRC_Q_DELETED:
            return "Queue has been deleted"
        case MQRC_Q_FULL:
            return "Queue is full"
        case MQRC_Q_NOT_EMPTY:
            return "Queue not empty"
        case MQRC_Q_SPACE_NOT_AVAILABLE:
            return "Queue space not available"
        case MQRC_Q_TYPE_ERROR:
            return "Queue type error"
        case MQRC_Q_MGR_NAME_ERROR:
            return "Queue manager name error"
        case MQRC_Q_MGR_NOT_AVAILABLE:
            return "Queue manager not available"
        case MQRC_REPORT_OPTIONS_ERROR:
            return "Report options error"
        case MQRC_SECOND_MARK_NOT_ALLOWED:
            return "Second mark not allowed"
        case MQRC_SECURITY_ERROR:
            return "Security error"
        case MQRC_SELECTOR_COUNT_ERROR:
            return "Selector count error"
        case MQRC_SELECTOR_LIMIT_EXCEEDED:
            return "Selector limit exceeded"
        case MQRC_SELECTOR_ERROR:
            return "Selector error"
        case MQRC_SELECTOR_NOT_FOR_TYPE:
            return "Selector not valid for type"
        case MQRC_SIGNAL_OUTSTANDING:
            return "Signal outstanding"
        case MQRC_SIGNAL_REQUEST_ACCEPTED:
            return "Signal request accepted"
        case MQRC_STORAGE_NOT_AVAILABLE:
            return "Storage not available"
        case MQRC_SYNCPOINT_NOT_AVAILABLE:
            return "Syncpoint not available"
        case MQRC_TRIGGER_CONTROL_ERROR:
            return "Trigger control error"
        case MQRC_TRIGGER_DEPTH_ERROR:
            return "Trigger depth error"
        case MQRC_TRIGGER_MSG_PRIORITY_ERR:
            return "Trigger message priority error"
        case MQRC_TRIGGER_TYPE_ERROR:
            return "Trigger type error"
        case MQRC_TRUNCATED_MSG_ACCEPTED:
            return "Truncated message accepted"
        case MQRC_TRUNCATED_MSG_FAILED:
            return "Message truncated"
        case MQRC_UNKNOWN_ALIAS_BASE_Q:
            return "Unknown alias base queue"
        case MQRC_UNKNOWN_OBJECT_NAME:
            return "Unknown object name"
        case MQRC_UNKNOWN_OBJECT_Q_MGR:
            return "Unknown object queue manager"
        case MQRC_UNKNOWN_REMOTE_Q_MGR:
            return "Unknown remote queue manager"
        case MQRC_WAIT_INTERVAL_ERROR:
            return "Wait interval error"
        case MQRC_XMIT_Q_TYPE_ERROR:
            return "Transmission queue type error"
        case MQRC_XMIT_Q_USAGE_ERROR:
            return "Transmission queue usage error"
        case MQRC_NOT_CONVERTED:
            return "Message not converted"
        case MQRC_CONVERTED_MSG_TOO_BIG:
            return "Converted message too big"
        case MQRC_OBJECT_DAMAGED:
            return "Object is damaged"
        case MQRC_CONNECTION_QUIESCING:
            return "Connection quiescing"
        case MQRC_CONNECTION_STOPPING:
            return "Connection stopping"
        case MQRC_CHANNEL_NOT_AVAILABLE:
            return "Channel not available"
        case MQRC_HOST_NOT_AVAILABLE:
            return "Host not available"
        case MQRC_SSL_INITIALIZATION_ERROR:
            return "TLS/SSL initialization error"
        case MQRC_SSL_NOT_ALLOWED:
            return "TLS/SSL not allowed"
        case MQRC_SSL_PEER_NAME_MISMATCH:
            return "TLS/SSL peer name mismatch"
        case MQRC_SSL_PEER_NAME_ERROR:
            return "TLS/SSL peer name error"
        default:
            return "Unknown reason code (\(reasonCode))"
        }
    }

    // MARK: - MQRC Constants

    // Define the most common MQRC constants for reference
    // These match the values from cmqc.h

    /// No reason to report (0)
    public static let MQRC_NONE: Int32 = 0

    /// Alias base queue type error (2001)
    public static let MQRC_ALIAS_BASE_Q_TYPE_ERROR: Int32 = 2001

    /// Already connected (2002)
    public static let MQRC_ALREADY_CONNECTED: Int32 = 2002

    /// Backed out (2003)
    public static let MQRC_BACKED_OUT: Int32 = 2003

    /// Buffer error (2004)
    public static let MQRC_BUFFER_ERROR: Int32 = 2004

    /// Buffer length error (2005)
    public static let MQRC_BUFFER_LENGTH_ERROR: Int32 = 2005

    /// Character attribute length error (2006)
    public static let MQRC_CHAR_ATTR_LENGTH_ERROR: Int32 = 2006

    /// Character attributes error (2007)
    public static let MQRC_CHAR_ATTRS_ERROR: Int32 = 2007

    /// Character attributes too short (2008)
    public static let MQRC_CHAR_ATTRS_TOO_SHORT: Int32 = 2008

    /// Connection broken (2009)
    public static let MQRC_CONNECTION_BROKEN: Int32 = 2009

    /// Data length error (2010)
    public static let MQRC_DATA_LENGTH_ERROR: Int32 = 2010

    /// Dynamic queue name error (2011)
    public static let MQRC_DYNAMIC_Q_NAME_ERROR: Int32 = 2011

    /// Environment error (2012)
    public static let MQRC_ENVIRONMENT_ERROR: Int32 = 2012

    /// Expiry error (2013)
    public static let MQRC_EXPIRY_ERROR: Int32 = 2013

    /// Feedback error (2014)
    public static let MQRC_FEEDBACK_ERROR: Int32 = 2014

    /// Get inhibited (2016)
    public static let MQRC_GET_INHIBITED: Int32 = 2016

    /// Handle not available (2017)
    public static let MQRC_HANDLE_NOT_AVAILABLE: Int32 = 2017

    /// Connection handle error (2018)
    public static let MQRC_HCONN_ERROR: Int32 = 2018

    /// Object handle error (2019)
    public static let MQRC_HOBJ_ERROR: Int32 = 2019

    /// Inhibit value error (2020)
    public static let MQRC_INHIBIT_VALUE_ERROR: Int32 = 2020

    /// Integer attribute count error (2021)
    public static let MQRC_INT_ATTR_COUNT_ERROR: Int32 = 2021

    /// Integer attribute count too small (2022)
    public static let MQRC_INT_ATTR_COUNT_TOO_SMALL: Int32 = 2022

    /// Integer attributes array error (2023)
    public static let MQRC_INT_ATTRS_ARRAY_ERROR: Int32 = 2023

    /// Syncpoint limit reached (2024)
    public static let MQRC_SYNCPOINT_LIMIT_REACHED: Int32 = 2024

    /// Maximum connections limit reached (2025)
    public static let MQRC_MAX_CONNS_LIMIT_REACHED: Int32 = 2025

    /// Message descriptor error (2026)
    public static let MQRC_MD_ERROR: Int32 = 2026

    /// Missing reply-to queue (2027)
    public static let MQRC_MISSING_REPLY_TO_Q: Int32 = 2027

    /// Message type error (2029)
    public static let MQRC_MSG_TYPE_ERROR: Int32 = 2029

    /// Message too big for queue (2030)
    public static let MQRC_MSG_TOO_BIG_FOR_Q: Int32 = 2030

    /// Message too big for queue manager (2031)
    public static let MQRC_MSG_TOO_BIG_FOR_Q_MGR: Int32 = 2031

    /// No message available (2033)
    public static let MQRC_NO_MSG_AVAILABLE: Int32 = 2033

    /// No message under cursor (2034)
    public static let MQRC_NO_MSG_UNDER_CURSOR: Int32 = 2034

    /// Not authorized (2035)
    public static let MQRC_NOT_AUTHORIZED: Int32 = 2035

    /// Not open for browse (2036)
    public static let MQRC_NOT_OPEN_FOR_BROWSE: Int32 = 2036

    /// Not open for input (2037)
    public static let MQRC_NOT_OPEN_FOR_INPUT: Int32 = 2037

    /// Not open for inquire (2038)
    public static let MQRC_NOT_OPEN_FOR_INQUIRE: Int32 = 2038

    /// Not open for output (2039)
    public static let MQRC_NOT_OPEN_FOR_OUTPUT: Int32 = 2039

    /// Not open for set (2040)
    public static let MQRC_NOT_OPEN_FOR_SET: Int32 = 2040

    /// Object changed (2041)
    public static let MQRC_OBJECT_CHANGED: Int32 = 2041

    /// Object in use (2042)
    public static let MQRC_OBJECT_IN_USE: Int32 = 2042

    /// Object type error (2043)
    public static let MQRC_OBJECT_TYPE_ERROR: Int32 = 2043

    /// Object descriptor error (2044)
    public static let MQRC_OD_ERROR: Int32 = 2044

    /// Option not valid for type (2045)
    public static let MQRC_OPTION_NOT_VALID_FOR_TYPE: Int32 = 2045

    /// Options error (2046)
    public static let MQRC_OPTIONS_ERROR: Int32 = 2046

    /// Persistence error (2047)
    public static let MQRC_PERSISTENCE_ERROR: Int32 = 2047

    /// Persistent not allowed (2048)
    public static let MQRC_PERSISTENT_NOT_ALLOWED: Int32 = 2048

    /// Priority exceeds maximum (2049)
    public static let MQRC_PRIORITY_EXCEEDS_MAXIMUM: Int32 = 2049

    /// Priority error (2050)
    public static let MQRC_PRIORITY_ERROR: Int32 = 2050

    /// Put inhibited (2051)
    public static let MQRC_PUT_INHIBITED: Int32 = 2051

    /// Queue deleted (2052)
    public static let MQRC_Q_DELETED: Int32 = 2052

    /// Queue full (2053)
    public static let MQRC_Q_FULL: Int32 = 2053

    /// Queue not empty (2055)
    public static let MQRC_Q_NOT_EMPTY: Int32 = 2055

    /// Queue space not available (2056)
    public static let MQRC_Q_SPACE_NOT_AVAILABLE: Int32 = 2056

    /// Queue type error (2057)
    public static let MQRC_Q_TYPE_ERROR: Int32 = 2057

    /// Queue manager name error (2058)
    public static let MQRC_Q_MGR_NAME_ERROR: Int32 = 2058

    /// Queue manager not available (2059)
    public static let MQRC_Q_MGR_NOT_AVAILABLE: Int32 = 2059

    /// Report options error (2061)
    public static let MQRC_REPORT_OPTIONS_ERROR: Int32 = 2061

    /// Second mark not allowed (2062)
    public static let MQRC_SECOND_MARK_NOT_ALLOWED: Int32 = 2062

    /// Security error (2063)
    public static let MQRC_SECURITY_ERROR: Int32 = 2063

    /// Selector count error (2065)
    public static let MQRC_SELECTOR_COUNT_ERROR: Int32 = 2065

    /// Selector limit exceeded (2066)
    public static let MQRC_SELECTOR_LIMIT_EXCEEDED: Int32 = 2066

    /// Selector error (2067)
    public static let MQRC_SELECTOR_ERROR: Int32 = 2067

    /// Selector not for type (2068)
    public static let MQRC_SELECTOR_NOT_FOR_TYPE: Int32 = 2068

    /// Signal outstanding (2069)
    public static let MQRC_SIGNAL_OUTSTANDING: Int32 = 2069

    /// Signal request accepted (2070)
    public static let MQRC_SIGNAL_REQUEST_ACCEPTED: Int32 = 2070

    /// Storage not available (2071)
    public static let MQRC_STORAGE_NOT_AVAILABLE: Int32 = 2071

    /// Syncpoint not available (2072)
    public static let MQRC_SYNCPOINT_NOT_AVAILABLE: Int32 = 2072

    /// Trigger control error (2075)
    public static let MQRC_TRIGGER_CONTROL_ERROR: Int32 = 2075

    /// Trigger depth error (2076)
    public static let MQRC_TRIGGER_DEPTH_ERROR: Int32 = 2076

    /// Trigger message priority error (2077)
    public static let MQRC_TRIGGER_MSG_PRIORITY_ERR: Int32 = 2077

    /// Trigger type error (2078)
    public static let MQRC_TRIGGER_TYPE_ERROR: Int32 = 2078

    /// Truncated message accepted (2079)
    public static let MQRC_TRUNCATED_MSG_ACCEPTED: Int32 = 2079

    /// Truncated message failed (2080)
    public static let MQRC_TRUNCATED_MSG_FAILED: Int32 = 2080

    /// Unknown alias base queue (2082)
    public static let MQRC_UNKNOWN_ALIAS_BASE_Q: Int32 = 2082

    /// Unknown object name (2085)
    public static let MQRC_UNKNOWN_OBJECT_NAME: Int32 = 2085

    /// Unknown object queue manager (2086)
    public static let MQRC_UNKNOWN_OBJECT_Q_MGR: Int32 = 2086

    /// Unknown remote queue manager (2087)
    public static let MQRC_UNKNOWN_REMOTE_Q_MGR: Int32 = 2087

    /// Wait interval error (2090)
    public static let MQRC_WAIT_INTERVAL_ERROR: Int32 = 2090

    /// Transmission queue type error (2091)
    public static let MQRC_XMIT_Q_TYPE_ERROR: Int32 = 2091

    /// Transmission queue usage error (2092)
    public static let MQRC_XMIT_Q_USAGE_ERROR: Int32 = 2092

    /// Object damaged (2101)
    public static let MQRC_OBJECT_DAMAGED: Int32 = 2101

    /// Not converted (2119)
    public static let MQRC_NOT_CONVERTED: Int32 = 2119

    /// Converted message too big (2120)
    public static let MQRC_CONVERTED_MSG_TOO_BIG: Int32 = 2120

    /// Connection quiescing (2202)
    public static let MQRC_CONNECTION_QUIESCING: Int32 = 2202

    /// Connection stopping (2203)
    public static let MQRC_CONNECTION_STOPPING: Int32 = 2203

    /// Channel not available (2537)
    public static let MQRC_CHANNEL_NOT_AVAILABLE: Int32 = 2537

    /// Host not available (2538)
    public static let MQRC_HOST_NOT_AVAILABLE: Int32 = 2538

    /// SSL initialization error (2393)
    public static let MQRC_SSL_INITIALIZATION_ERROR: Int32 = 2393

    /// SSL not allowed (2396)
    public static let MQRC_SSL_NOT_ALLOWED: Int32 = 2396

    /// SSL peer name mismatch (2398)
    public static let MQRC_SSL_PEER_NAME_MISMATCH: Int32 = 2398

    /// SSL peer name error (2399)
    public static let MQRC_SSL_PEER_NAME_ERROR: Int32 = 2399
}
