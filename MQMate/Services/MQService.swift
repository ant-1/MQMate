import Foundation
import CMQC

// MARK: - MQ Error Types

/// Errors that can occur during MQ operations
public enum MQError: Error, LocalizedError {
    /// Connection to queue manager failed
    case connectionFailed(reason: MQLong, description: String)
    /// Disconnection from queue manager failed
    case disconnectFailed(reason: MQLong, description: String)
    /// Not connected to a queue manager
    case notConnected
    /// Operation failed with completion and reason codes
    case operationFailed(operation: String, completionCode: MQLong, reason: MQLong)
    /// Invalid configuration provided
    case invalidConfiguration(message: String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason, let description):
            return "Connection failed (MQRC \(reason)): \(description)"
        case .disconnectFailed(let reason, let description):
            return "Disconnect failed (MQRC \(reason)): \(description)"
        case .notConnected:
            return "Not connected to a queue manager"
        case .operationFailed(let operation, let completionCode, let reason):
            return "\(operation) failed with completion code \(completionCode), reason \(reason)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}

// MARK: - MQ Service Protocol

/// Protocol defining MQ service operations
public protocol MQServiceProtocol {
    /// Current connection state
    var isConnected: Bool { get }

    /// Connect to a queue manager
    func connect(
        queueManager: String,
        channel: String,
        host: String,
        port: Int,
        username: String?,
        password: String?
    ) async throws

    /// Disconnect from the current queue manager
    func disconnect()
}

// MARK: - MQ Service Implementation

/// Service for interacting with IBM MQ queue managers
/// Provides connect/disconnect functionality using the IBM MQ C client library
@MainActor
public final class MQService: MQServiceProtocol {

    // MARK: - Properties

    /// Connection handle for the current queue manager connection
    /// Initialized to MQHC_UNUSABLE_HCONN to indicate no active connection
    private var connectionHandle: MQHCONN = MQHC_UNUSABLE_HCONN

    /// Name of the currently connected queue manager
    private(set) var connectedQueueManager: String?

    /// Check if currently connected to a queue manager
    public var isConnected: Bool {
        return connectionHandle != MQHC_UNUSABLE_HCONN
    }

    // MARK: - Initialization

    public init() {
        // Initialize with no connection
    }

    deinit {
        // Ensure we disconnect when the service is deallocated
        // Note: This is synchronous disconnect to ensure cleanup
        disconnectSync()
    }

    // MARK: - Connection Methods

    /// Connect to an IBM MQ queue manager using client connection
    /// - Parameters:
    ///   - queueManager: Name of the queue manager to connect to
    ///   - channel: Server connection channel name
    ///   - host: Hostname or IP address of the queue manager
    ///   - port: Port number for the connection (typically 1414)
    ///   - username: Optional username for authentication
    ///   - password: Optional password for authentication
    /// - Throws: MQError if connection fails
    public func connect(
        queueManager: String,
        channel: String,
        host: String,
        port: Int,
        username: String?,
        password: String?
    ) async throws {
        // Disconnect if already connected
        if isConnected {
            disconnect()
        }

        // Validate inputs
        guard !queueManager.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue manager name cannot be empty")
        }
        guard !channel.isEmpty else {
            throw MQError.invalidConfiguration(message: "Channel name cannot be empty")
        }
        guard !host.isEmpty else {
            throw MQError.invalidConfiguration(message: "Host cannot be empty")
        }
        guard port > 0 && port <= 65535 else {
            throw MQError.invalidConfiguration(message: "Port must be between 1 and 65535")
        }

        // Perform connection on background thread to avoid blocking UI
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task.detached { [self] in
                do {
                    try await MainActor.run {
                        try self.performConnect(
                            queueManager: queueManager,
                            channel: channel,
                            host: host,
                            port: port,
                            username: username,
                            password: password
                        )
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Perform the actual MQ connection (must be called on main actor)
    private func performConnect(
        queueManager: String,
        channel: String,
        host: String,
        port: Int,
        username: String?,
        password: String?
    ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Initialize Channel Descriptor (MQCD)
        var channelDescriptor = MQCD()
        channelDescriptor.Version = MQCD_VERSION_11
        channelDescriptor.ChannelType = MQCHT_CLNTCONN
        channelDescriptor.TransportType = MQXPT_TCP

        // Set channel name (max 20 characters, space-padded)
        let channelChars = channel.toMQCharArray(length: Int(MQ_CHANNEL_NAME_LENGTH))
        withUnsafeMutablePointer(to: &channelDescriptor.ChannelName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_CHANNEL_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_CHANNEL_NAME_LENGTH) {
                bound[i] = channelChars[i]
            }
        }

        // Set connection name (host(port))
        let connectionName = "\(host)(\(port))"
        let connectionChars = connectionName.toMQCharArray(length: Int(MQ_CONN_NAME_LENGTH))
        withUnsafeMutablePointer(to: &channelDescriptor.ConnectionName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_CONN_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_CONN_NAME_LENGTH) {
                bound[i] = connectionChars[i]
            }
        }

        // Initialize Connection Options (MQCNO)
        var connectOptions = MQCNO()
        connectOptions.Version = MQCNO_VERSION_5
        connectOptions.Options = MQCNO_HANDLE_SHARE_BLOCK

        // Set the channel definition pointer
        withUnsafeMutablePointer(to: &channelDescriptor) { cdPtr in
            connectOptions.ClientConnPtr = UnsafeMutableRawPointer(cdPtr)
        }

        // Configure authentication if credentials provided
        var securityParams = MQCSP()
        if let username = username, !username.isEmpty,
           let password = password, !password.isEmpty {
            securityParams.Version = MQCSP_VERSION_1
            securityParams.AuthenticationType = MQCSP_AUTH_USER_ID_AND_PWD

            // Set user ID
            let userIdData = username.data(using: .utf8)!
            userIdData.withUnsafeBytes { rawBuffer in
                if let baseAddress = rawBuffer.baseAddress {
                    securityParams.CSPUserIdPtr = UnsafeMutableRawPointer(mutating: baseAddress)
                    securityParams.CSPUserIdLength = MQLONG(username.utf8.count)
                }
            }

            // Set password
            let passwordData = password.data(using: .utf8)!
            passwordData.withUnsafeBytes { rawBuffer in
                if let baseAddress = rawBuffer.baseAddress {
                    securityParams.CSPPasswordPtr = UnsafeMutableRawPointer(mutating: baseAddress)
                    securityParams.CSPPasswordLength = MQLONG(password.utf8.count)
                }
            }

            withUnsafeMutablePointer(to: &securityParams) { cspPtr in
                connectOptions.SecurityParmsPtr = UnsafeMutableRawPointer(cspPtr)
            }
        }

        // Prepare queue manager name (space-padded to 48 characters)
        var qmNameChars = queueManager.toMQCharArray(length: Int(MQ_Q_MGR_NAME_LENGTH))

        // Call MQCONNX to connect to the queue manager
        qmNameChars.withUnsafeMutableBufferPointer { qmBuffer in
            withUnsafeMutablePointer(to: &connectOptions) { cnoPtr in
                MQCONNX(
                    qmBuffer.baseAddress,
                    cnoPtr,
                    &connectionHandle,
                    &compCode,
                    &reason
                )
            }
        }

        // Check result
        guard compCode != MQCC_FAILED else {
            connectionHandle = MQHC_UNUSABLE_HCONN
            let reasonCode = MQReasonCode(rawValue: reason)
            throw MQError.connectionFailed(
                reason: reason,
                description: reasonCode.localizedDescription
            )
        }

        // Store connected queue manager name
        connectedQueueManager = queueManager
    }

    /// Disconnect from the current queue manager
    /// Safe to call even if not connected
    public func disconnect() {
        disconnectSync()
    }

    /// Synchronous disconnect implementation
    /// Used by both public disconnect() and deinit
    private func disconnectSync() {
        guard connectionHandle != MQHC_UNUSABLE_HCONN else {
            // Already disconnected, nothing to do
            return
        }

        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Call MQDISC to disconnect from the queue manager
        MQDISC(&connectionHandle, &compCode, &reason)

        // Reset handle regardless of result to ensure we don't try to reuse it
        connectionHandle = MQHC_UNUSABLE_HCONN
        connectedQueueManager = nil

        // Note: We don't throw on disconnect failure - just log if needed
        // This ensures cleanup always completes
        if compCode == MQCC_FAILED {
            // In production, consider logging this error
            // For now, we silently handle it to ensure cleanup
        }
    }

    // MARK: - Internal Accessors

    /// Get the current connection handle (for use by other MQ operations)
    /// - Returns: The connection handle or throws if not connected
    internal func getConnectionHandle() throws -> MQHCONN {
        guard connectionHandle != MQHC_UNUSABLE_HCONN else {
            throw MQError.notConnected
        }
        return connectionHandle
    }
}

// MARK: - Helper Extensions for MQService

private extension String {
    /// Convert Swift String to MQ fixed-length character array (padded with spaces)
    func toMQCharArray(length: Int) -> [MQCHAR] {
        var chars = Array<MQCHAR>(repeating: MQCHAR(0x20), count: length) // Space-padded
        let utf8 = self.utf8
        let copyLength = min(utf8.count, length)
        for (index, char) in utf8.prefix(copyLength).enumerated() {
            chars[index] = MQCHAR(bitPattern: char)
        }
        return chars
    }
}
