import Foundation
import CMQC

// MARK: - MQ Service Protocol
// Note: MQError is defined in Models/MQError.swift

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

    /// Get information about a specific queue
    func getQueueInfo(queueName: String) throws -> MQService.QueueInfo

    /// List all queues in the connected queue manager
    func listQueues(filter: String) async throws -> [MQService.QueueInfo]

    /// Create a new queue in the connected queue manager
    func createQueue(queueName: String, queueType: MQQueueType, maxDepth: Int32?) async throws

    /// Delete an existing queue from the connected queue manager
    func deleteQueue(queueName: String) async throws

    /// Purge all messages from a queue using destructive MQGET
    func purgeQueue(queueName: String) async throws -> Int

    /// Send a message to a queue using MQPUT
    func sendMessage(
        queueName: String,
        payload: Data,
        correlationId: [UInt8]?,
        replyToQueue: String?,
        messageType: MQService.MQMessageType,
        persistence: MQService.MQMessagePersistence,
        priority: Int32?
    ) async throws -> [UInt8]

    /// Delete a specific message from a queue using destructive MQGET with message ID match
    func deleteMessage(queueName: String, messageId: [UInt8]) async throws
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
        // Note: Cleanup is handled by explicit disconnect() calls
        // We cannot call actor-isolated methods from deinit
        // The connection handle will be invalidated when the process exits
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
            throw MQError.connectionFailed(
                reasonCode: reason,
                queueManager: queueManager
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

    // MARK: - Queue Operations

    /// Queue information returned from MQINQ operations
    public struct QueueInfo: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let queueType: MQQueueType
        public let currentDepth: Int32
        public let maxDepth: Int32
        public let openInputCount: Int32
        public let openOutputCount: Int32
        public let inhibitGet: Bool
        public let inhibitPut: Bool

        public init(
            name: String,
            queueType: MQQueueType = .unknown,
            currentDepth: Int32 = 0,
            maxDepth: Int32 = 0,
            openInputCount: Int32 = 0,
            openOutputCount: Int32 = 0,
            inhibitGet: Bool = false,
            inhibitPut: Bool = false
        ) {
            self.id = name
            self.name = name
            self.queueType = queueType
            self.currentDepth = currentDepth
            self.maxDepth = maxDepth
            self.openInputCount = openInputCount
            self.openOutputCount = openOutputCount
            self.inhibitGet = inhibitGet
            self.inhibitPut = inhibitPut
        }
    }

    /// Open a queue for the specified operations
    /// - Parameters:
    ///   - queueName: Name of the queue to open
    ///   - options: MQOO_* options for opening the queue
    /// - Returns: Object handle for the opened queue
    /// - Throws: MQError if the queue cannot be opened
    private func openQueue(queueName: String, options: MQLONG) throws -> MQHOBJ {
        guard isConnected else {
            throw MQError.notConnected
        }

        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE
        var objectHandle: MQHOBJ = MQHO_UNUSABLE_HOBJ

        // Initialize Object Descriptor (MQOD)
        var objectDescriptor = MQOD()
        objectDescriptor.Version = MQOD_VERSION_4

        // Set object type to queue
        objectDescriptor.ObjectType = MQOT_Q

        // Set queue name (max 48 characters, space-padded)
        let queueNameChars = queueName.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &objectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = queueNameChars[i]
            }
        }

        // Call MQOPEN
        MQOPEN(
            connectionHandle,
            &objectDescriptor,
            options,
            &objectHandle,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQOPEN(\(queueName))",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        return objectHandle
    }

    /// Close an open queue
    /// - Parameter objectHandle: Handle returned from openQueue
    private func closeQueue(_ objectHandle: inout MQHOBJ) {
        guard objectHandle != MQHO_UNUSABLE_HOBJ else { return }

        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        MQCLOSE(
            connectionHandle,
            &objectHandle,
            MQCO_NONE,
            &compCode,
            &reason
        )

        objectHandle = MQHO_UNUSABLE_HOBJ
    }

    /// Inquire queue attributes using MQINQ
    /// - Parameters:
    ///   - objectHandle: Handle to an open queue
    ///   - queueName: Name of the queue (for constructing QueueInfo)
    /// - Returns: QueueInfo with the queue's attributes
    /// - Throws: MQError if inquiry fails
    private func inquireQueueAttributes(objectHandle: MQHOBJ, queueName: String) throws -> QueueInfo {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Selectors for integer attributes we want to inquire
        var selectors: [MQLONG] = [
            MQIA_Q_TYPE,
            MQIA_CURRENT_Q_DEPTH,
            MQIA_MAX_Q_DEPTH,
            MQIA_OPEN_INPUT_COUNT,
            MQIA_OPEN_OUTPUT_COUNT,
            MQIA_INHIBIT_GET,
            MQIA_INHIBIT_PUT
        ]

        // Buffer for integer attribute values
        var intAttrs = [MQLONG](repeating: 0, count: selectors.count)

        // No character attributes in this query
        let charAttrLength: MQLONG = 0
        var charAttrs = [MQCHAR]()

        MQINQ(
            connectionHandle,
            objectHandle,
            MQLONG(selectors.count),
            &selectors,
            MQLONG(intAttrs.count),
            &intAttrs,
            charAttrLength,
            &charAttrs,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQINQ(\(queueName))",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        // Parse the results
        let queueType = MQQueueType(rawValue: intAttrs[0])
        let currentDepth = intAttrs[1]
        let maxDepth = intAttrs[2]
        let openInputCount = intAttrs[3]
        let openOutputCount = intAttrs[4]
        let inhibitGet = intAttrs[5] == MQQA_GET_INHIBITED
        let inhibitPut = intAttrs[6] == MQQA_PUT_INHIBITED

        return QueueInfo(
            name: queueName,
            queueType: queueType,
            currentDepth: currentDepth,
            maxDepth: maxDepth,
            openInputCount: openInputCount,
            openOutputCount: openOutputCount,
            inhibitGet: inhibitGet,
            inhibitPut: inhibitPut
        )
    }

    /// Get information about a specific queue
    /// - Parameter queueName: Name of the queue to inquire
    /// - Returns: QueueInfo with the queue's attributes
    /// - Throws: MQError if the queue cannot be accessed
    public func getQueueInfo(queueName: String) throws -> QueueInfo {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Open queue for inquiry
        var objectHandle = try openQueue(
            queueName: queueName,
            options: MQOO_INQUIRE | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&objectHandle)
        }

        // Inquire attributes
        return try inquireQueueAttributes(objectHandle: objectHandle, queueName: queueName)
    }

    /// List all queues in the connected queue manager
    /// Uses PCF (Programmable Command Format) to discover queue names
    /// - Parameter filter: Optional filter pattern (e.g., "DEV.*" or "*"). Defaults to "*"
    /// - Returns: Array of QueueInfo for all discovered queues
    /// - Throws: MQError if listing fails
    public func listQueues(filter: String = "*") async throws -> [QueueInfo] {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Build and send PCF inquiry command to discover queue names
        let queueNames = try sendPCFInquireQueue(filter: filter)

        // Get detailed info for each discovered queue
        var queues: [QueueInfo] = []
        for name in queueNames {
            do {
                let info = try getQueueInfo(queueName: name)
                queues.append(info)
            } catch {
                // Skip queues we can't access (e.g., authorization issues)
                // but continue with others
                continue
            }
        }

        return queues.sorted { $0.name < $1.name }
    }

    /// Send a PCF MQCMD_INQUIRE_Q command to discover queue names
    /// - Parameter filter: Filter pattern for queue names
    /// - Returns: Array of queue names matching the filter
    /// - Throws: MQError if the PCF command fails
    private func sendPCFInquireQueue(filter: String) throws -> [String] {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Open the command queue for sending PCF commands
        var adminObjectHandle = try openQueue(
            queueName: "SYSTEM.ADMIN.COMMAND.QUEUE",
            options: MQOO_OUTPUT | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&adminObjectHandle)
        }

        // Generate a unique reply queue name
        let replyQueueModel = "SYSTEM.DEFAULT.MODEL.QUEUE"
        let replyQueuePrefix = "MQMATE.REPLY.*"

        // Open a dynamic reply queue
        var replyObjectDescriptor = MQOD()
        replyObjectDescriptor.Version = MQOD_VERSION_4
        replyObjectDescriptor.ObjectType = MQOT_Q

        // Set model queue name
        let modelQueueChars = replyQueueModel.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = modelQueueChars[i]
            }
        }

        // Set dynamic queue name prefix
        let dynamicQueueChars = replyQueuePrefix.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.DynamicQName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = dynamicQueueChars[i]
            }
        }

        var replyObjectHandle: MQHOBJ = MQHO_UNUSABLE_HOBJ
        MQOPEN(
            connectionHandle,
            &replyObjectDescriptor,
            MQOO_INPUT_EXCLUSIVE | MQOO_FAIL_IF_QUIESCING,
            &replyObjectHandle,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQOPEN(reply queue)",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        defer {
            var handle = replyObjectHandle
            closeQueue(&handle)
        }

        // Extract the actual dynamic queue name
        var replyQueueName = [MQCHAR](repeating: 0x20, count: Int(MQ_Q_NAME_LENGTH))
        withUnsafePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                replyQueueName[i] = bound[i]
            }
        }

        // Build PCF message for MQCMD_INQUIRE_Q
        let pcfMessage = try buildPCFInquireQueueMessage(
            filter: filter,
            replyQueueName: replyQueueName
        )

        // Send the PCF command
        try sendPCFMessage(
            objectHandle: adminObjectHandle,
            message: pcfMessage,
            replyQueueName: replyQueueName
        )

        // Receive and parse the response(s)
        return try receivePCFResponse(replyObjectHandle: replyObjectHandle)
    }

    /// Build a PCF MQCMD_INQUIRE_Q message
    private func buildPCFInquireQueueMessage(
        filter: String,
        replyQueueName: [MQCHAR]
    ) throws -> Data {
        // PCF Header structure
        var pcfHeader = MQCFH()
        pcfHeader.Type = MQCFT_COMMAND
        pcfHeader.StrucLength = MQCFH_STRUC_LENGTH
        pcfHeader.Version = MQCFH_VERSION_1
        pcfHeader.Command = MQCMD_INQUIRE_Q
        pcfHeader.MsgSeqNumber = 1
        pcfHeader.Control = MQCFC_LAST
        pcfHeader.ParameterCount = 2 // Queue name filter + queue type

        var message = Data()

        // Append header
        withUnsafeBytes(of: &pcfHeader) { buffer in
            message.append(contentsOf: buffer)
        }

        // Add MQCACF_Q_NAME parameter (string parameter for queue name filter)
        var qNameParam = MQCFST()
        qNameParam.Type = MQCFT_STRING
        qNameParam.StrucLength = MQCFST_STRUC_LENGTH_FIXED + Int32(MQ_Q_NAME_LENGTH)
        qNameParam.Parameter = MQCA_Q_NAME
        qNameParam.CodedCharSetId = MQCCSI_DEFAULT
        qNameParam.StringLength = Int32(MQ_Q_NAME_LENGTH)

        withUnsafeBytes(of: &qNameParam) { buffer in
            // Only append up to the String field (before the actual string data)
            message.append(contentsOf: buffer.prefix(MemoryLayout<MQCFST>.size - MemoryLayout<MQCHAR>.size))
        }

        // Append the filter string (space-padded to 48 chars)
        let filterChars = filter.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        message.append(contentsOf: filterChars.map { UInt8(bitPattern: $0) })

        // Add MQIA_Q_TYPE parameter (integer parameter requesting all queue types)
        var qTypeParam = MQCFIN()
        qTypeParam.Type = MQCFT_INTEGER
        qTypeParam.StrucLength = MQCFIN_STRUC_LENGTH
        qTypeParam.Parameter = MQIA_Q_TYPE
        qTypeParam.Value = MQQT_ALL

        withUnsafeBytes(of: &qTypeParam) { buffer in
            message.append(contentsOf: buffer)
        }

        return message
    }

    /// Send a PCF message to the admin queue
    private func sendPCFMessage(
        objectHandle: MQHOBJ,
        message: Data,
        replyQueueName: [MQCHAR]
    ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Message descriptor
        var messageDescriptor = MQMD()
        messageDescriptor.Version = MQMD_VERSION_2
        messageDescriptor.Format = (
            MQCHAR(0x4D), MQCHAR(0x51), MQCHAR(0x48), MQCHAR(0x52),
            MQCHAR(0x46), MQCHAR(0x32), MQCHAR(0x20), MQCHAR(0x20)
        )  // "MQHRF2  "
        messageDescriptor.MsgType = MQMT_REQUEST
        messageDescriptor.Expiry = 300 * 10 // 5 minutes in tenths of a second

        // Set reply-to queue name
        withUnsafeMutablePointer(to: &messageDescriptor.ReplyToQ) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = replyQueueName[i]
            }
        }

        // Put message options
        var putOptions = MQPMO()
        putOptions.Version = MQPMO_VERSION_2
        putOptions.Options = MQPMO_NO_SYNCPOINT | MQPMO_NEW_MSG_ID | MQPMO_NEW_CORREL_ID

        // Put the message
        var messageData = [UInt8](message)
        var messageLength = MQLONG(messageData.count)

        MQPUT(
            connectionHandle,
            objectHandle,
            &messageDescriptor,
            &putOptions,
            messageLength,
            &messageData,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQPUT(PCF command)",
                completionCode: compCode,
                reasonCode: reason
            )
        }
    }

    /// Receive and parse PCF response messages
    private func receivePCFResponse(replyObjectHandle: MQHOBJ) throws -> [String] {
        var queueNames: [String] = []
        var hasMoreMessages = true
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        while hasMoreMessages {
            // Message descriptor
            var messageDescriptor = MQMD()
            messageDescriptor.Version = MQMD_VERSION_2

            // Get message options
            var getOptions = MQGMO()
            getOptions.Version = MQGMO_VERSION_2
            getOptions.Options = MQGMO_NO_SYNCPOINT | MQGMO_WAIT | MQGMO_CONVERT
            getOptions.WaitInterval = 5000 // 5 second timeout
            getOptions.MatchOptions = MQMO_NONE

            // Buffer for response
            var buffer = [UInt8](repeating: 0, count: 65536)
            var dataLength: MQLONG = 0

            MQGET(
                connectionHandle,
                replyObjectHandle,
                &messageDescriptor,
                &getOptions,
                MQLONG(buffer.count),
                &buffer,
                &dataLength,
                &compCode,
                &reason
            )

            if reason == MQRC_NO_MSG_AVAILABLE {
                hasMoreMessages = false
                break
            }

            guard compCode != MQCC_FAILED else {
                if reason == MQRC_NO_MSG_AVAILABLE {
                    break
                }
                throw MQError.operationFailed(
                    operation: "MQGET(PCF response)",
                    completionCode: compCode,
                    reasonCode: reason
                )
            }

            // Parse the PCF response to extract queue names
            let responseData = Data(buffer.prefix(Int(dataLength)))
            let names = parsePCFQueueResponse(data: responseData)
            queueNames.append(contentsOf: names)

            // Check if this is the last message in the response
            if responseData.count >= MemoryLayout<MQCFH>.size {
                let control: Int32 = responseData.withUnsafeBytes { ptr in
                    // Control field is at offset 20 in MQCFH
                    ptr.load(fromByteOffset: 20, as: Int32.self)
                }
                if control == MQCFC_LAST {
                    hasMoreMessages = false
                }
            }
        }

        return queueNames
    }

    /// Parse a PCF response message to extract queue names
    private func parsePCFQueueResponse(data: Data) -> [String] {
        var names: [String] = []
        var offset = 0

        guard data.count >= MemoryLayout<MQCFH>.size else {
            return names
        }

        // Read PCF header
        let headerSize = Int(MemoryLayout<MQCFH>.size)
        offset = headerSize

        // Parse parameters
        while offset + 12 < data.count {
            let paramType: Int32 = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: Int32.self)
            }
            let strucLength: Int32 = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset + 4, as: Int32.self)
            }
            let parameter: Int32 = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset + 8, as: Int32.self)
            }

            if paramType == MQCFT_STRING && parameter == MQCA_Q_NAME {
                // String parameter - extract queue name
                let stringLength: Int32 = data.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset + 16, as: Int32.self)
                }
                let stringOffset = offset + 20
                let stringEnd = min(stringOffset + Int(stringLength), data.count)

                if stringOffset < stringEnd {
                    let stringData = data[stringOffset..<stringEnd]
                    if let name = String(data: stringData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespaces) {
                        if !name.isEmpty {
                            names.append(name)
                        }
                    }
                }
            }

            offset += Int(strucLength)

            // Safety check to prevent infinite loop
            if strucLength <= 0 {
                break
            }
        }

        return names
    }

    // MARK: - Message Browsing Operations

    /// Message information returned from MQGET browse operations
    public struct MQMessage: Identifiable, Sendable {
        /// Unique identifier for the message (hex-encoded message ID)
        public let id: String
        /// Raw message ID bytes (24 bytes)
        public let messageId: [UInt8]
        /// Correlation ID bytes (24 bytes)
        public let correlationId: [UInt8]
        /// Message format (e.g., "MQSTR", "MQHRF2")
        public let format: String
        /// Message payload as raw data
        public let payload: Data
        /// Message payload as string (if decodable as UTF-8)
        public let payloadString: String?
        /// Put timestamp (when message was put to queue)
        public let putDateTime: Date?
        /// Put application name
        public let putApplicationName: String
        /// Message type (request, reply, datagram, report)
        public let messageType: MQMessageType
        /// Persistence (persistent or not persistent)
        public let persistence: MQMessagePersistence
        /// Message priority (0-9)
        public let priority: Int32
        /// Reply-to queue name
        public let replyToQueue: String
        /// Reply-to queue manager name
        public let replyToQueueManager: String
        /// Message sequence number within group
        public let messageSequenceNumber: Int32
        /// Message position (index in browse cursor, 0-based)
        public let position: Int

        public init(
            messageId: [UInt8],
            correlationId: [UInt8],
            format: String,
            payload: Data,
            putDateTime: Date?,
            putApplicationName: String,
            messageType: MQMessageType,
            persistence: MQMessagePersistence,
            priority: Int32,
            replyToQueue: String,
            replyToQueueManager: String,
            messageSequenceNumber: Int32,
            position: Int
        ) {
            self.messageId = messageId
            self.correlationId = correlationId
            self.id = messageId.map { String(format: "%02X", $0) }.joined()
            self.format = format
            self.payload = payload
            self.payloadString = String(data: payload, encoding: .utf8)
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

        /// Correlation ID as hex string
        public var correlationIdHex: String {
            correlationId.map { String(format: "%02X", $0) }.joined()
        }

        /// Check if payload appears to be binary (non-printable characters)
        public var isBinaryPayload: Bool {
            guard let string = payloadString else { return true }
            // Check if the string contains mostly printable characters
            let printableCount = string.unicodeScalars.filter { CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces).contains($0) }.count
            return Double(printableCount) / Double(max(string.count, 1)) < 0.8
        }
    }

    /// Message type enumeration
    public enum MQMessageType: Int32, Sendable {
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

        public var displayName: String {
            switch self {
            case .datagram: return "Datagram"
            case .request: return "Request"
            case .reply: return "Reply"
            case .report: return "Report"
            case .unknown: return "Unknown"
            }
        }

        /// Returns the MQMT_* constant value for use in MQMD
        public var mqValue: MQLONG {
            return MQLONG(self.rawValue)
        }
    }

    /// Message persistence enumeration
    public enum MQMessagePersistence: Int32, Sendable {
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

        public var displayName: String {
            switch self {
            case .notPersistent: return "Not Persistent"
            case .persistent: return "Persistent"
            case .asQueueDef: return "As Queue Def"
            case .unknown: return "Unknown"
            }
        }
    }

    /// Browse messages in a queue without removing them
    /// Uses MQGET with MQGMO_BROWSE_FIRST and MQGMO_BROWSE_NEXT options
    /// - Parameters:
    ///   - queueName: Name of the queue to browse
    ///   - maxMessages: Maximum number of messages to retrieve (default: 100)
    ///   - maxMessageSize: Maximum size per message in bytes (default: 4MB)
    /// - Returns: Array of MQMessage objects
    /// - Throws: MQError if browsing fails
    public func browseMessages(
        queueName: String,
        maxMessages: Int = 100,
        maxMessageSize: Int = 4 * 1024 * 1024
    ) async throws -> [MQMessage] {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Open queue for browsing
        var objectHandle = try openQueue(
            queueName: queueName,
            options: MQOO_BROWSE | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&objectHandle)
        }

        return try performBrowseMessages(
            objectHandle: objectHandle,
            queueName: queueName,
            maxMessages: maxMessages,
            maxMessageSize: maxMessageSize
        )
    }

    /// Perform the actual message browsing operation
    private func performBrowseMessages(
        objectHandle: MQHOBJ,
        queueName: String,
        maxMessages: Int,
        maxMessageSize: Int
    ) throws -> [MQMessage] {
        var messages: [MQMessage] = []
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE
        var isFirstMessage = true
        var position = 0

        // Buffer for message data
        var buffer = [UInt8](repeating: 0, count: maxMessageSize)

        while messages.count < maxMessages {
            // Initialize message descriptor for each MQGET call
            var messageDescriptor = MQMD()
            messageDescriptor.Version = MQMD_VERSION_2

            // Initialize get message options
            var getOptions = MQGMO()
            getOptions.Version = MQGMO_VERSION_2

            // Use BROWSE_FIRST for the first message, BROWSE_NEXT for subsequent
            if isFirstMessage {
                getOptions.Options = MQGMO_BROWSE_FIRST | MQGMO_NO_SYNCPOINT | MQGMO_CONVERT | MQGMO_ACCEPT_TRUNCATED_MSG | MQGMO_FAIL_IF_QUIESCING
                isFirstMessage = false
            } else {
                getOptions.Options = MQGMO_BROWSE_NEXT | MQGMO_NO_SYNCPOINT | MQGMO_CONVERT | MQGMO_ACCEPT_TRUNCATED_MSG | MQGMO_FAIL_IF_QUIESCING
            }

            // No wait - return immediately if no message
            getOptions.WaitInterval = 0
            getOptions.MatchOptions = MQMO_NONE

            var dataLength: MQLONG = 0

            // Call MQGET to browse the message
            MQGET(
                connectionHandle,
                objectHandle,
                &messageDescriptor,
                &getOptions,
                MQLONG(buffer.count),
                &buffer,
                &dataLength,
                &compCode,
                &reason
            )

            // Check for no more messages
            if reason == MQRC_NO_MSG_AVAILABLE {
                break
            }

            // Check for errors (allow truncated messages)
            if compCode == MQCC_FAILED && reason != MQRC_TRUNCATED_MSG_FAILED {
                throw MQError.operationFailed(
                    operation: "MQGET(browse \(queueName))",
                    completionCode: compCode,
                    reasonCode: reason
                )
            }

            // Extract message data from descriptor
            let message = extractMessageFromDescriptor(
                messageDescriptor: messageDescriptor,
                buffer: buffer,
                dataLength: dataLength,
                position: position
            )
            messages.append(message)
            position += 1
        }

        return messages
    }

    /// Extract message information from MQMD and payload buffer
    private func extractMessageFromDescriptor(
        messageDescriptor: MQMD,
        buffer: [UInt8],
        dataLength: MQLONG,
        position: Int
    ) -> MQMessage {
        // Extract message ID (24 bytes)
        var messageId = [UInt8](repeating: 0, count: Int(MQ_MSG_ID_LENGTH))
        withUnsafePointer(to: messageDescriptor.MsgId) { ptr in
            let bound = ptr.withMemoryRebound(to: UInt8.self, capacity: Int(MQ_MSG_ID_LENGTH)) { $0 }
            for i in 0..<Int(MQ_MSG_ID_LENGTH) {
                messageId[i] = bound[i]
            }
        }

        // Extract correlation ID (24 bytes)
        var correlationId = [UInt8](repeating: 0, count: Int(MQ_CORREL_ID_LENGTH))
        withUnsafePointer(to: messageDescriptor.CorrelId) { ptr in
            let bound = ptr.withMemoryRebound(to: UInt8.self, capacity: Int(MQ_CORREL_ID_LENGTH)) { $0 }
            for i in 0..<Int(MQ_CORREL_ID_LENGTH) {
                correlationId[i] = bound[i]
            }
        }

        // Extract format string (8 characters)
        var formatChars = [MQCHAR](repeating: 0x20, count: Int(MQ_FORMAT_LENGTH))
        withUnsafePointer(to: messageDescriptor.Format) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_FORMAT_LENGTH)) { $0 }
            for i in 0..<Int(MQ_FORMAT_LENGTH) {
                formatChars[i] = bound[i]
            }
        }
        let format = String(bytes: formatChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Extract put application name (28 characters)
        var putApplNameChars = [MQCHAR](repeating: 0x20, count: Int(MQ_PUT_APPL_NAME_LENGTH))
        withUnsafePointer(to: messageDescriptor.PutApplName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_PUT_APPL_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_PUT_APPL_NAME_LENGTH) {
                putApplNameChars[i] = bound[i]
            }
        }
        let putApplicationName = String(bytes: putApplNameChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Extract reply-to queue name (48 characters)
        var replyToQChars = [MQCHAR](repeating: 0x20, count: Int(MQ_Q_NAME_LENGTH))
        withUnsafePointer(to: messageDescriptor.ReplyToQ) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                replyToQChars[i] = bound[i]
            }
        }
        let replyToQueue = String(bytes: replyToQChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Extract reply-to queue manager name (48 characters)
        var replyToQMgrChars = [MQCHAR](repeating: 0x20, count: Int(MQ_Q_MGR_NAME_LENGTH))
        withUnsafePointer(to: messageDescriptor.ReplyToQMgr) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_MGR_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_MGR_NAME_LENGTH) {
                replyToQMgrChars[i] = bound[i]
            }
        }
        let replyToQueueManager = String(bytes: replyToQMgrChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Parse put date/time
        let putDateTime = parsePutDateTime(messageDescriptor: messageDescriptor)

        // Extract payload
        let payloadSize = min(Int(dataLength), buffer.count)
        let payload = Data(buffer.prefix(payloadSize))

        return MQMessage(
            messageId: messageId,
            correlationId: correlationId,
            format: format,
            payload: payload,
            putDateTime: putDateTime,
            putApplicationName: putApplicationName,
            messageType: MQMessageType(rawValue: messageDescriptor.MsgType),
            persistence: MQMessagePersistence(rawValue: messageDescriptor.Persistence),
            priority: messageDescriptor.Priority,
            replyToQueue: replyToQueue,
            replyToQueueManager: replyToQueueManager,
            messageSequenceNumber: messageDescriptor.MsgSeqNumber,
            position: position
        )
    }

    /// Parse put date and time from MQMD fields
    private func parsePutDateTime(messageDescriptor: MQMD) -> Date? {
        // Extract PutDate (8 characters: YYYYMMDD)
        var putDateChars = [MQCHAR](repeating: 0x20, count: Int(MQ_PUT_DATE_LENGTH))
        withUnsafePointer(to: messageDescriptor.PutDate) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_PUT_DATE_LENGTH)) { $0 }
            for i in 0..<Int(MQ_PUT_DATE_LENGTH) {
                putDateChars[i] = bound[i]
            }
        }
        let putDateString = String(bytes: putDateChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Extract PutTime (8 characters: HHMMSSTH)
        var putTimeChars = [MQCHAR](repeating: 0x20, count: Int(MQ_PUT_TIME_LENGTH))
        withUnsafePointer(to: messageDescriptor.PutTime) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_PUT_TIME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_PUT_TIME_LENGTH) {
                putTimeChars[i] = bound[i]
            }
        }
        let putTimeString = String(bytes: putTimeChars.map { UInt8(bitPattern: $0) }, encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Parse date and time
        guard putDateString.count >= 8, putTimeString.count >= 6 else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let dateTimeString = String(putDateString.prefix(8)) + String(putTimeString.prefix(6))
        return dateFormatter.date(from: dateTimeString)
    }

    /// Browse a single message at a specific position
    /// - Parameters:
    ///   - queueName: Name of the queue to browse
    ///   - position: Position of the message (0-based index)
    ///   - maxMessageSize: Maximum size per message in bytes (default: 4MB)
    /// - Returns: MQMessage at the specified position, or nil if not found
    /// - Throws: MQError if browsing fails
    public func browseMessageAt(
        queueName: String,
        position: Int,
        maxMessageSize: Int = 4 * 1024 * 1024
    ) async throws -> MQMessage? {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Browse messages up to and including the specified position
        let messages = try await browseMessages(
            queueName: queueName,
            maxMessages: position + 1,
            maxMessageSize: maxMessageSize
        )

        // Return the message at the specified position if it exists
        guard position < messages.count else {
            return nil
        }

        return messages[position]
    }

    /// Get the count of messages currently in a queue
    /// This is a convenience method that uses getQueueInfo
    /// - Parameter queueName: Name of the queue
    /// - Returns: Number of messages in the queue
    /// - Throws: MQError if inquiry fails
    public func getMessageCount(queueName: String) throws -> Int32 {
        let queueInfo = try getQueueInfo(queueName: queueName)
        return queueInfo.currentDepth
    }

    // MARK: - Queue Management Operations

    /// Create a new queue in the connected queue manager
    /// Uses PCF MQCMD_CREATE_Q command to create the queue
    /// - Parameters:
    ///   - queueName: Name of the queue to create (max 48 characters)
    ///   - queueType: Type of queue to create (local, alias, remote, model)
    ///   - maxDepth: Maximum depth of the queue (optional, uses queue manager default if nil)
    /// - Throws: MQError if queue creation fails
    public func createQueue(
        queueName: String,
        queueType: MQQueueType = .local,
        maxDepth: Int32? = nil
    ) async throws {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Validate queue name
        guard !queueName.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue name cannot be empty")
        }

        guard queueName.count <= Int(MQ_Q_NAME_LENGTH) else {
            throw MQError.invalidConfiguration(message: "Queue name cannot exceed 48 characters")
        }

        // Send PCF create queue command
        try sendPCFCreateQueue(
            queueName: queueName,
            queueType: queueType,
            maxDepth: maxDepth
        )
    }

    /// Send a PCF MQCMD_CREATE_Q command to create a new queue
    /// - Parameters:
    ///   - queueName: Name of the queue to create
    ///   - queueType: Type of queue to create
    ///   - maxDepth: Maximum depth of the queue (optional)
    /// - Throws: MQError if the PCF command fails
    private func sendPCFCreateQueue(
        queueName: String,
        queueType: MQQueueType,
        maxDepth: Int32?
    ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Open the command queue for sending PCF commands
        var adminObjectHandle = try openQueue(
            queueName: "SYSTEM.ADMIN.COMMAND.QUEUE",
            options: MQOO_OUTPUT | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&adminObjectHandle)
        }

        // Generate a unique reply queue name
        let replyQueueModel = "SYSTEM.DEFAULT.MODEL.QUEUE"
        let replyQueuePrefix = "MQMATE.REPLY.*"

        // Open a dynamic reply queue
        var replyObjectDescriptor = MQOD()
        replyObjectDescriptor.Version = MQOD_VERSION_4
        replyObjectDescriptor.ObjectType = MQOT_Q

        // Set model queue name
        let modelQueueChars = replyQueueModel.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = modelQueueChars[i]
            }
        }

        // Set dynamic queue name prefix
        let dynamicQueueChars = replyQueuePrefix.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.DynamicQName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = dynamicQueueChars[i]
            }
        }

        var replyObjectHandle: MQHOBJ = MQHO_UNUSABLE_HOBJ
        MQOPEN(
            connectionHandle,
            &replyObjectDescriptor,
            MQOO_INPUT_EXCLUSIVE | MQOO_FAIL_IF_QUIESCING,
            &replyObjectHandle,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQOPEN(reply queue for create)",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        defer {
            var handle = replyObjectHandle
            closeQueue(&handle)
        }

        // Extract the actual dynamic queue name
        var replyQueueName = [MQCHAR](repeating: 0x20, count: Int(MQ_Q_NAME_LENGTH))
        withUnsafePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                replyQueueName[i] = bound[i]
            }
        }

        // Build PCF message for MQCMD_CREATE_Q
        let pcfMessage = try buildPCFCreateQueueMessage(
            queueName: queueName,
            queueType: queueType,
            maxDepth: maxDepth,
            replyQueueName: replyQueueName
        )

        // Send the PCF command
        try sendPCFMessage(
            objectHandle: adminObjectHandle,
            message: pcfMessage,
            replyQueueName: replyQueueName
        )

        // Receive and check the response for errors
        try receivePCFCreateQueueResponse(replyObjectHandle: replyObjectHandle)
    }

    /// Build a PCF MQCMD_CREATE_Q message
    /// - Parameters:
    ///   - queueName: Name of the queue to create
    ///   - queueType: Type of queue to create
    ///   - maxDepth: Maximum depth of the queue (optional)
    ///   - replyQueueName: Reply queue name for response
    /// - Returns: PCF message data
    private func buildPCFCreateQueueMessage(
        queueName: String,
        queueType: MQQueueType,
        maxDepth: Int32?,
        replyQueueName: [MQCHAR]
    ) throws -> Data {
        // Determine parameter count based on optional parameters
        var parameterCount: Int32 = 2 // Queue name + queue type (required)
        if maxDepth != nil {
            parameterCount += 1
        }

        // PCF Header structure
        var pcfHeader = MQCFH()
        pcfHeader.Type = MQCFT_COMMAND
        pcfHeader.StrucLength = MQCFH_STRUC_LENGTH
        pcfHeader.Version = MQCFH_VERSION_1
        pcfHeader.Command = MQCMD_CREATE_Q
        pcfHeader.MsgSeqNumber = 1
        pcfHeader.Control = MQCFC_LAST
        pcfHeader.ParameterCount = parameterCount

        var message = Data()

        // Append header
        withUnsafeBytes(of: &pcfHeader) { buffer in
            message.append(contentsOf: buffer)
        }

        // Add MQCA_Q_NAME parameter (string parameter for queue name)
        var qNameParam = MQCFST()
        qNameParam.Type = MQCFT_STRING
        qNameParam.StrucLength = MQCFST_STRUC_LENGTH_FIXED + Int32(MQ_Q_NAME_LENGTH)
        qNameParam.Parameter = MQCA_Q_NAME
        qNameParam.CodedCharSetId = MQCCSI_DEFAULT
        qNameParam.StringLength = Int32(MQ_Q_NAME_LENGTH)

        withUnsafeBytes(of: &qNameParam) { buffer in
            // Only append up to the String field (before the actual string data)
            message.append(contentsOf: buffer.prefix(MemoryLayout<MQCFST>.size - MemoryLayout<MQCHAR>.size))
        }

        // Append the queue name string (space-padded to 48 chars)
        let queueNameChars = queueName.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        message.append(contentsOf: queueNameChars.map { UInt8(bitPattern: $0) })

        // Add MQIA_Q_TYPE parameter (integer parameter for queue type)
        var qTypeParam = MQCFIN()
        qTypeParam.Type = MQCFT_INTEGER
        qTypeParam.StrucLength = MQCFIN_STRUC_LENGTH
        qTypeParam.Parameter = MQIA_Q_TYPE
        qTypeParam.Value = queueType.rawValue

        withUnsafeBytes(of: &qTypeParam) { buffer in
            message.append(contentsOf: buffer)
        }

        // Add MQIA_MAX_Q_DEPTH parameter if specified
        if let maxDepth = maxDepth {
            var maxDepthParam = MQCFIN()
            maxDepthParam.Type = MQCFT_INTEGER
            maxDepthParam.StrucLength = MQCFIN_STRUC_LENGTH
            maxDepthParam.Parameter = MQIA_MAX_Q_DEPTH
            maxDepthParam.Value = maxDepth

            withUnsafeBytes(of: &maxDepthParam) { buffer in
                message.append(contentsOf: buffer)
            }
        }

        return message
    }

    /// Receive and validate PCF response for queue creation
    /// - Parameter replyObjectHandle: Handle to the reply queue
    /// - Throws: MQError if the queue creation failed
    private func receivePCFCreateQueueResponse(replyObjectHandle: MQHOBJ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Message descriptor
        var messageDescriptor = MQMD()
        messageDescriptor.Version = MQMD_VERSION_2

        // Get message options
        var getOptions = MQGMO()
        getOptions.Version = MQGMO_VERSION_2
        getOptions.Options = MQGMO_NO_SYNCPOINT | MQGMO_WAIT | MQGMO_CONVERT
        getOptions.WaitInterval = 30000 // 30 second timeout for admin commands
        getOptions.MatchOptions = MQMO_NONE

        // Buffer for response
        var buffer = [UInt8](repeating: 0, count: 65536)
        var dataLength: MQLONG = 0

        MQGET(
            connectionHandle,
            replyObjectHandle,
            &messageDescriptor,
            &getOptions,
            MQLONG(buffer.count),
            &buffer,
            &dataLength,
            &compCode,
            &reason
        )

        if reason == MQRC_NO_MSG_AVAILABLE {
            throw MQError.operationFailed(
                operation: "Create queue (no response received)",
                completionCode: MQCC_FAILED,
                reasonCode: reason
            )
        }

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQGET(PCF create queue response)",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        // Parse the PCF response header to check for errors
        let responseData = Data(buffer.prefix(Int(dataLength)))
        try validatePCFResponse(data: responseData, operation: "Create queue")
    }

    /// Validate a PCF response for success or error
    /// - Parameters:
    ///   - data: The PCF response data
    ///   - operation: Description of the operation for error messages
    /// - Throws: MQError if the PCF response indicates failure
    private func validatePCFResponse(data: Data, operation: String) throws {
        guard data.count >= MemoryLayout<MQCFH>.size else {
            throw MQError.operationFailed(
                operation: operation,
                completionCode: MQCC_FAILED,
                reasonCode: MQRC_UNEXPECTED_ERROR
            )
        }

        // Read the completion code and reason from the PCF header
        // CompCode is at offset 24, Reason is at offset 28 in MQCFH
        let pcfCompCode: Int32 = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 24, as: Int32.self)
        }
        let pcfReason: Int32 = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 28, as: Int32.self)
        }

        guard pcfCompCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: operation,
                completionCode: pcfCompCode,
                reasonCode: pcfReason
            )
        }
    }

    /// Delete an existing queue from the connected queue manager
    /// Uses PCF MQCMD_DELETE_Q command to delete the queue
    /// - Parameter queueName: Name of the queue to delete (max 48 characters)
    /// - Throws: MQError if queue deletion fails
    public func deleteQueue(queueName: String) async throws {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Validate queue name
        guard !queueName.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue name cannot be empty")
        }

        guard queueName.count <= Int(MQ_Q_NAME_LENGTH) else {
            throw MQError.invalidConfiguration(message: "Queue name cannot exceed 48 characters")
        }

        // Send PCF delete queue command
        try sendPCFDeleteQueue(queueName: queueName)
    }

    /// Send a PCF MQCMD_DELETE_Q command to delete a queue
    /// - Parameter queueName: Name of the queue to delete
    /// - Throws: MQError if the PCF command fails
    private func sendPCFDeleteQueue(queueName: String) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Open the command queue for sending PCF commands
        var adminObjectHandle = try openQueue(
            queueName: "SYSTEM.ADMIN.COMMAND.QUEUE",
            options: MQOO_OUTPUT | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&adminObjectHandle)
        }

        // Generate a unique reply queue name
        let replyQueueModel = "SYSTEM.DEFAULT.MODEL.QUEUE"
        let replyQueuePrefix = "MQMATE.REPLY.*"

        // Open a dynamic reply queue
        var replyObjectDescriptor = MQOD()
        replyObjectDescriptor.Version = MQOD_VERSION_4
        replyObjectDescriptor.ObjectType = MQOT_Q

        // Set model queue name
        let modelQueueChars = replyQueueModel.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = modelQueueChars[i]
            }
        }

        // Set dynamic queue name prefix
        let dynamicQueueChars = replyQueuePrefix.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        withUnsafeMutablePointer(to: &replyObjectDescriptor.DynamicQName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                bound[i] = dynamicQueueChars[i]
            }
        }

        var replyObjectHandle: MQHOBJ = MQHO_UNUSABLE_HOBJ
        MQOPEN(
            connectionHandle,
            &replyObjectDescriptor,
            MQOO_INPUT_EXCLUSIVE | MQOO_FAIL_IF_QUIESCING,
            &replyObjectHandle,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQOPEN(reply queue for delete)",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        defer {
            var handle = replyObjectHandle
            closeQueue(&handle)
        }

        // Extract the actual dynamic queue name
        var replyQueueName = [MQCHAR](repeating: 0x20, count: Int(MQ_Q_NAME_LENGTH))
        withUnsafePointer(to: &replyObjectDescriptor.ObjectName) { ptr in
            let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
            for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                replyQueueName[i] = bound[i]
            }
        }

        // Build PCF message for MQCMD_DELETE_Q
        let pcfMessage = try buildPCFDeleteQueueMessage(
            queueName: queueName,
            replyQueueName: replyQueueName
        )

        // Send the PCF command
        try sendPCFMessage(
            objectHandle: adminObjectHandle,
            message: pcfMessage,
            replyQueueName: replyQueueName
        )

        // Receive and check the response for errors
        try receivePCFDeleteQueueResponse(replyObjectHandle: replyObjectHandle)
    }

    /// Build a PCF MQCMD_DELETE_Q message
    /// - Parameters:
    ///   - queueName: Name of the queue to delete
    ///   - replyQueueName: Reply queue name for response
    /// - Returns: PCF message data
    private func buildPCFDeleteQueueMessage(
        queueName: String,
        replyQueueName: [MQCHAR]
    ) throws -> Data {
        // PCF Header structure
        var pcfHeader = MQCFH()
        pcfHeader.Type = MQCFT_COMMAND
        pcfHeader.StrucLength = MQCFH_STRUC_LENGTH
        pcfHeader.Version = MQCFH_VERSION_1
        pcfHeader.Command = MQCMD_DELETE_Q
        pcfHeader.MsgSeqNumber = 1
        pcfHeader.Control = MQCFC_LAST
        pcfHeader.ParameterCount = 1 // Only queue name required

        var message = Data()

        // Append header
        withUnsafeBytes(of: &pcfHeader) { buffer in
            message.append(contentsOf: buffer)
        }

        // Add MQCA_Q_NAME parameter (string parameter for queue name)
        var qNameParam = MQCFST()
        qNameParam.Type = MQCFT_STRING
        qNameParam.StrucLength = MQCFST_STRUC_LENGTH_FIXED + Int32(MQ_Q_NAME_LENGTH)
        qNameParam.Parameter = MQCA_Q_NAME
        qNameParam.CodedCharSetId = MQCCSI_DEFAULT
        qNameParam.StringLength = Int32(MQ_Q_NAME_LENGTH)

        withUnsafeBytes(of: &qNameParam) { buffer in
            // Only append up to the String field (before the actual string data)
            message.append(contentsOf: buffer.prefix(MemoryLayout<MQCFST>.size - MemoryLayout<MQCHAR>.size))
        }

        // Append the queue name string (space-padded to 48 chars)
        let queueNameChars = queueName.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
        message.append(contentsOf: queueNameChars.map { UInt8(bitPattern: $0) })

        return message
    }

    /// Receive and validate PCF response for queue deletion
    /// - Parameter replyObjectHandle: Handle to the reply queue
    /// - Throws: MQError if the queue deletion failed
    private func receivePCFDeleteQueueResponse(replyObjectHandle: MQHOBJ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Message descriptor
        var messageDescriptor = MQMD()
        messageDescriptor.Version = MQMD_VERSION_2

        // Get message options
        var getOptions = MQGMO()
        getOptions.Version = MQGMO_VERSION_2
        getOptions.Options = MQGMO_NO_SYNCPOINT | MQGMO_WAIT | MQGMO_CONVERT
        getOptions.WaitInterval = 30000 // 30 second timeout for admin commands
        getOptions.MatchOptions = MQMO_NONE

        // Buffer for response
        var buffer = [UInt8](repeating: 0, count: 65536)
        var dataLength: MQLONG = 0

        MQGET(
            connectionHandle,
            replyObjectHandle,
            &messageDescriptor,
            &getOptions,
            MQLONG(buffer.count),
            &buffer,
            &dataLength,
            &compCode,
            &reason
        )

        if reason == MQRC_NO_MSG_AVAILABLE {
            throw MQError.operationFailed(
                operation: "Delete queue (no response received)",
                completionCode: MQCC_FAILED,
                reasonCode: reason
            )
        }

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQGET(PCF delete queue response)",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        // Parse the PCF response header to check for errors
        let responseData = Data(buffer.prefix(Int(dataLength)))
        try validatePCFResponse(data: responseData, operation: "Delete queue")
    }

    // MARK: - Queue Purge Operations

    /// Purge all messages from a queue using destructive MQGET
    /// This method reads and discards all messages in the queue
    /// - Parameter queueName: Name of the queue to purge
    /// - Returns: Number of messages purged
    /// - Throws: MQError if purging fails
    public func purgeQueue(queueName: String) async throws -> Int {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Validate queue name
        guard !queueName.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue name cannot be empty")
        }

        // Open queue for destructive input
        var objectHandle = try openQueue(
            queueName: queueName,
            options: MQOO_INPUT_SHARED | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&objectHandle)
        }

        return try performPurgeQueue(objectHandle: objectHandle, queueName: queueName)
    }

    /// Perform the destructive MQGET loop to purge all messages
    /// - Parameters:
    ///   - objectHandle: Handle to the open queue
    ///   - queueName: Name of the queue (for error messages)
    /// - Returns: Number of messages purged
    /// - Throws: MQError if purging fails
    private func performPurgeQueue(objectHandle: MQHOBJ, queueName: String) throws -> Int {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE
        var purgedCount = 0

        // Small buffer - we don't need the actual message content
        // We just need to destructively read each message
        var buffer = [UInt8](repeating: 0, count: 1)

        while true {
            // Initialize message descriptor for each MQGET call
            var messageDescriptor = MQMD()
            messageDescriptor.Version = MQMD_VERSION_2

            // Initialize get message options
            var getOptions = MQGMO()
            getOptions.Version = MQGMO_VERSION_2
            // Use NO_SYNCPOINT for immediate removal, ACCEPT_TRUNCATED_MSG since we don't care about content
            getOptions.Options = MQGMO_NO_SYNCPOINT | MQGMO_ACCEPT_TRUNCATED_MSG | MQGMO_FAIL_IF_QUIESCING
            getOptions.WaitInterval = 0 // No wait - return immediately if no message
            getOptions.MatchOptions = MQMO_NONE

            var dataLength: MQLONG = 0

            // Call MQGET to destructively read the message
            MQGET(
                connectionHandle,
                objectHandle,
                &messageDescriptor,
                &getOptions,
                MQLONG(buffer.count),
                &buffer,
                &dataLength,
                &compCode,
                &reason
            )

            // Check for no more messages
            if reason == MQRC_NO_MSG_AVAILABLE {
                break
            }

            // Handle truncation - this is expected since our buffer is minimal
            if compCode == MQCC_WARNING && reason == MQRC_TRUNCATED_MSG_ACCEPTED {
                // Message was successfully removed, just truncated in buffer
                purgedCount += 1
                continue
            }

            // Check for other errors
            if compCode == MQCC_FAILED {
                throw MQError.operationFailed(
                    operation: "MQGET(purge \(queueName))",
                    completionCode: compCode,
                    reasonCode: reason
                )
            }

            // Message successfully removed
            purgedCount += 1
        }

        return purgedCount
    }

    // MARK: - Message Send Operations

    /// Send a message to a queue using MQPUT
    /// - Parameters:
    ///   - queueName: Name of the queue to send to
    ///   - payload: Message payload as Data
    ///   - correlationId: Optional correlation ID (24 bytes, padded with zeros if shorter)
    ///   - replyToQueue: Optional reply-to queue name
    ///   - messageType: Type of message (datagram, request, reply, report)
    ///   - persistence: Message persistence setting
    ///   - priority: Optional message priority (0-9, nil uses queue default)
    /// - Returns: The message ID assigned to the sent message (24 bytes)
    /// - Throws: MQError if sending fails
    public func sendMessage(
        queueName: String,
        payload: Data,
        correlationId: [UInt8]? = nil,
        replyToQueue: String? = nil,
        messageType: MQMessageType = .datagram,
        persistence: MQMessagePersistence = .asQueueDef,
        priority: Int32? = nil
    ) async throws -> [UInt8] {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Validate queue name
        guard !queueName.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue name cannot be empty")
        }

        // Open queue for output
        var objectHandle = try openQueue(
            queueName: queueName,
            options: MQOO_OUTPUT | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&objectHandle)
        }

        return try performSendMessage(
            objectHandle: objectHandle,
            queueName: queueName,
            payload: payload,
            correlationId: correlationId,
            replyToQueue: replyToQueue,
            messageType: messageType,
            persistence: persistence,
            priority: priority
        )
    }

    /// Perform the actual MQPUT operation
    /// - Parameters:
    ///   - objectHandle: Handle to the open queue
    ///   - queueName: Name of the queue (for error messages)
    ///   - payload: Message payload as Data
    ///   - correlationId: Optional correlation ID
    ///   - replyToQueue: Optional reply-to queue name
    ///   - messageType: Type of message
    ///   - persistence: Message persistence setting
    ///   - priority: Optional message priority
    /// - Returns: The message ID assigned to the sent message
    /// - Throws: MQError if MQPUT fails
    private func performSendMessage(
        objectHandle: MQHOBJ,
        queueName: String,
        payload: Data,
        correlationId: [UInt8]?,
        replyToQueue: String?,
        messageType: MQMessageType,
        persistence: MQMessagePersistence,
        priority: Int32?
    ) throws -> [UInt8] {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Initialize message descriptor
        var messageDescriptor = MQMD()
        messageDescriptor.Version = MQMD_VERSION_2

        // Set format to MQSTR (string) for text messages
        // Format is an 8-character field: "MQSTR   "
        let formatChars: (MQCHAR, MQCHAR, MQCHAR, MQCHAR, MQCHAR, MQCHAR, MQCHAR, MQCHAR) = (
            MQCHAR(0x4D), MQCHAR(0x51), MQCHAR(0x53), MQCHAR(0x54),
            MQCHAR(0x52), MQCHAR(0x20), MQCHAR(0x20), MQCHAR(0x20)
        )  // "MQSTR   "
        messageDescriptor.Format = formatChars

        // Set message type
        messageDescriptor.MsgType = messageType.mqValue

        // Set persistence
        messageDescriptor.Persistence = persistence.rawValue

        // Set priority (-1 means use queue default per MQPRI_PRIORITY_AS_Q_DEF)
        if let priority = priority {
            messageDescriptor.Priority = priority
        } else {
            messageDescriptor.Priority = -1 // MQPRI_PRIORITY_AS_Q_DEF
        }

        // Set correlation ID if provided
        if let correlationId = correlationId {
            withUnsafeMutablePointer(to: &messageDescriptor.CorrelId) { ptr in
                let bound = ptr.withMemoryRebound(to: UInt8.self, capacity: Int(MQ_CORREL_ID_LENGTH)) { $0 }
                for i in 0..<Int(MQ_CORREL_ID_LENGTH) {
                    if i < correlationId.count {
                        bound[i] = correlationId[i]
                    } else {
                        bound[i] = 0x00
                    }
                }
            }
        }

        // Set reply-to queue if provided
        if let replyToQueue = replyToQueue, !replyToQueue.isEmpty {
            let replyToQueueChars = replyToQueue.toMQCharArray(length: Int(MQ_Q_NAME_LENGTH))
            withUnsafeMutablePointer(to: &messageDescriptor.ReplyToQ) { ptr in
                let bound = ptr.withMemoryRebound(to: MQCHAR.self, capacity: Int(MQ_Q_NAME_LENGTH)) { $0 }
                for i in 0..<Int(MQ_Q_NAME_LENGTH) {
                    bound[i] = replyToQueueChars[i]
                }
            }
        }

        // Initialize put message options
        var putOptions = MQPMO()
        putOptions.Version = MQPMO_VERSION_2
        putOptions.Options = MQPMO_NO_SYNCPOINT | MQPMO_NEW_MSG_ID

        // Prepare message data
        var messageData = [UInt8](payload)
        let messageLength = MQLONG(messageData.count)

        // Call MQPUT to send the message
        MQPUT(
            connectionHandle,
            objectHandle,
            &messageDescriptor,
            &putOptions,
            messageLength,
            &messageData,
            &compCode,
            &reason
        )

        guard compCode != MQCC_FAILED else {
            throw MQError.operationFailed(
                operation: "MQPUT(\(queueName))",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        // Extract and return the assigned message ID
        var messageId = [UInt8](repeating: 0, count: Int(MQ_MSG_ID_LENGTH))
        withUnsafePointer(to: messageDescriptor.MsgId) { ptr in
            let bound = ptr.withMemoryRebound(to: UInt8.self, capacity: Int(MQ_MSG_ID_LENGTH)) { $0 }
            for i in 0..<Int(MQ_MSG_ID_LENGTH) {
                messageId[i] = bound[i]
            }
        }

        return messageId
    }

    // MARK: - Message Delete Operations

    /// Delete a specific message from a queue using destructive MQGET with message ID match
    /// - Parameters:
    ///   - queueName: Name of the queue containing the message
    ///   - messageId: The message ID of the message to delete (24 bytes)
    /// - Throws: MQError if deletion fails or message not found
    public func deleteMessage(queueName: String, messageId: [UInt8]) async throws {
        guard isConnected else {
            throw MQError.notConnected
        }

        // Validate queue name
        guard !queueName.isEmpty else {
            throw MQError.invalidConfiguration(message: "Queue name cannot be empty")
        }

        // Validate message ID
        guard !messageId.isEmpty else {
            throw MQError.invalidConfiguration(message: "Message ID cannot be empty")
        }

        // Open queue for destructive input
        var objectHandle = try openQueue(
            queueName: queueName,
            options: MQOO_INPUT_SHARED | MQOO_FAIL_IF_QUIESCING
        )

        defer {
            closeQueue(&objectHandle)
        }

        try performDeleteMessage(
            objectHandle: objectHandle,
            queueName: queueName,
            messageId: messageId
        )
    }

    /// Perform the destructive MQGET with message ID matching
    /// - Parameters:
    ///   - objectHandle: Handle to the open queue
    ///   - queueName: Name of the queue (for error messages)
    ///   - messageId: The message ID to match
    /// - Throws: MQError if deletion fails or message not found
    private func performDeleteMessage(
        objectHandle: MQHOBJ,
        queueName: String,
        messageId: [UInt8]
    ) throws {
        var compCode: MQLONG = MQCC_OK
        var reason: MQLONG = MQRC_NONE

        // Initialize message descriptor
        var messageDescriptor = MQMD()
        messageDescriptor.Version = MQMD_VERSION_2

        // Set the message ID to match
        // Pad or truncate to exactly MQ_MSG_ID_LENGTH (24 bytes)
        withUnsafeMutablePointer(to: &messageDescriptor.MsgId) { ptr in
            let bound = ptr.withMemoryRebound(to: UInt8.self, capacity: Int(MQ_MSG_ID_LENGTH)) { $0 }
            for i in 0..<Int(MQ_MSG_ID_LENGTH) {
                if i < messageId.count {
                    bound[i] = messageId[i]
                } else {
                    bound[i] = 0x00
                }
            }
        }

        // Initialize get message options
        var getOptions = MQGMO()
        getOptions.Version = MQGMO_VERSION_2
        // Use NO_SYNCPOINT for immediate removal, ACCEPT_TRUNCATED_MSG since we don't care about content
        getOptions.Options = MQGMO_NO_SYNCPOINT | MQGMO_ACCEPT_TRUNCATED_MSG | MQGMO_FAIL_IF_QUIESCING
        getOptions.WaitInterval = 0 // No wait - return immediately if no message
        // Match on message ID only
        getOptions.MatchOptions = MQMO_MATCH_MSG_ID

        // Small buffer - we don't need the actual message content
        var buffer = [UInt8](repeating: 0, count: 1)
        var dataLength: MQLONG = 0

        // Call MQGET to destructively read the message
        MQGET(
            connectionHandle,
            objectHandle,
            &messageDescriptor,
            &getOptions,
            MQLONG(buffer.count),
            &buffer,
            &dataLength,
            &compCode,
            &reason
        )

        // Check for message not found
        if reason == MQRC_NO_MSG_AVAILABLE {
            throw MQError.operationFailed(
                operation: "Delete message (message not found in \(queueName))",
                completionCode: MQCC_FAILED,
                reasonCode: reason
            )
        }

        // Handle truncation - this is expected since our buffer is minimal
        if compCode == MQCC_WARNING && reason == MQRC_TRUNCATED_MSG_ACCEPTED {
            // Message was successfully removed, just truncated in buffer
            return
        }

        // Check for other errors
        if compCode == MQCC_FAILED {
            throw MQError.operationFailed(
                operation: "MQGET(delete message from \(queueName))",
                completionCode: compCode,
                reasonCode: reason
            )
        }

        // Message successfully removed
    }
}

// Note: toMQCharArray extension is defined in MQBridge/MQTypes.swift
