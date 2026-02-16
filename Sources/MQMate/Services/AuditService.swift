import Foundation

// MARK: - AuditService Protocol

/// Protocol defining audit logging operations for tracking destructive actions
public protocol AuditServiceProtocol: Sendable {
    /// Log a new audit entry
    /// - Parameter entry: The audit entry to log
    func log(_ entry: AuditEntry)

    /// Log a new audit entry with individual parameters
    /// - Parameters:
    ///   - actionType: Type of action being logged
    ///   - resource: Name of the affected resource
    ///   - details: Optional additional details
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    func log(
        actionType: AuditEntry.ActionType,
        resource: String,
        details: String?,
        queueManager: String?,
        username: String?
    )

    /// Get all audit log entries
    /// - Returns: Array of audit entries, most recent first
    func getAuditLog() -> [AuditEntry]

    /// Get audit log entries filtered by action type
    /// - Parameter actionType: The action type to filter by
    /// - Returns: Array of matching audit entries
    func getAuditLog(for actionType: AuditEntry.ActionType) -> [AuditEntry]

    /// Get audit log entries filtered by date range
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Array of matching audit entries
    func getAuditLog(from startDate: Date, to endDate: Date) -> [AuditEntry]

    /// Export audit log to a file
    /// - Parameter url: File URL to export to
    /// - Throws: Error if export fails
    func exportAuditLog(to url: URL) throws

    /// Export audit log as JSON data
    /// - Returns: JSON-encoded audit log data
    /// - Throws: Error if encoding fails
    func exportAuditLogAsJSON() throws -> Data

    /// Clear all audit log entries
    func clearAuditLog()

    /// Get the count of audit entries
    var entryCount: Int { get }
}

// MARK: - AuditService Implementation

/// Service for logging and tracking all destructive operations in MQMate
/// Maintains an in-memory log with optional file export for compliance and debugging
public final class AuditService: AuditServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// In-memory storage for audit entries
    private var entries: [AuditEntry] = []

    /// Lock for thread-safe access to entries
    private let lock = NSLock()

    /// Maximum number of entries to retain in memory (0 = unlimited)
    public let maxEntries: Int

    /// Whether to output entries to console/stderr
    public let consoleOutput: Bool

    /// Shared instance for app-wide audit logging
    public static let shared = AuditService()

    // MARK: - Initialization

    /// Create a new AuditService instance
    /// - Parameters:
    ///   - maxEntries: Maximum entries to retain (0 = unlimited, default: 1000)
    ///   - consoleOutput: Whether to log to console (default: true)
    public init(maxEntries: Int = 1000, consoleOutput: Bool = true) {
        self.maxEntries = maxEntries
        self.consoleOutput = consoleOutput
    }

    // MARK: - Public Methods

    /// Log a new audit entry
    /// - Parameter entry: The audit entry to log
    public func log(_ entry: AuditEntry) {
        lock.lock()
        defer { lock.unlock() }

        // Add entry to the beginning (most recent first)
        entries.insert(entry, at: 0)

        // Trim if exceeding max entries
        if maxEntries > 0 && entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Output to console if enabled
        if consoleOutput {
            outputToConsole(entry)
        }
    }

    /// Log a new audit entry with individual parameters
    /// - Parameters:
    ///   - actionType: Type of action being logged
    ///   - resource: Name of the affected resource
    ///   - details: Optional additional details
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func log(
        actionType: AuditEntry.ActionType,
        resource: String,
        details: String? = nil,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        let entry = AuditEntry(
            actionType: actionType,
            resource: resource,
            details: details,
            queueManager: queueManager,
            username: username
        )
        log(entry)
    }

    /// Get all audit log entries
    /// - Returns: Array of audit entries, most recent first
    public func getAuditLog() -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries
    }

    /// Get audit log entries filtered by action type
    /// - Parameter actionType: The action type to filter by
    /// - Returns: Array of matching audit entries
    public func getAuditLog(for actionType: AuditEntry.ActionType) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries.filter { $0.actionType == actionType }
    }

    /// Get audit log entries filtered by date range
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Array of matching audit entries
    public func getAuditLog(from startDate: Date, to endDate: Date) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
    }

    /// Export audit log to a file
    /// - Parameter url: File URL to export to
    /// - Throws: Error if export fails
    public func exportAuditLog(to url: URL) throws {
        let data = try exportAuditLogAsJSON()
        try data.write(to: url, options: .atomic)
    }

    /// Export audit log as JSON data
    /// - Returns: JSON-encoded audit log data
    /// - Throws: Error if encoding fails
    public func exportAuditLogAsJSON() throws -> Data {
        lock.lock()
        let entriesToExport = entries
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(entriesToExport)
    }

    /// Export audit log as formatted text
    /// - Returns: Human-readable audit log text
    public func exportAuditLogAsText() -> String {
        lock.lock()
        let entriesToExport = entries
        lock.unlock()

        var lines: [String] = [
            "MQMate Audit Log",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            String(repeating: "=", count: 80),
            ""
        ]

        for entry in entriesToExport {
            lines.append(entry.logDescription)
        }

        if entriesToExport.isEmpty {
            lines.append("No audit entries recorded.")
        }

        lines.append("")
        lines.append(String(repeating: "=", count: 80))
        lines.append("Total entries: \(entriesToExport.count)")

        return lines.joined(separator: "\n")
    }

    /// Clear all audit log entries
    public func clearAuditLog() {
        lock.lock()
        defer { lock.unlock() }

        entries.removeAll()
    }

    /// Get the count of audit entries
    public var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return entries.count
    }

    // MARK: - Convenience Logging Methods

    /// Log a message deletion
    /// - Parameters:
    ///   - messageId: The message ID being deleted
    ///   - queueName: Name of the queue
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func logMessageDeleted(
        messageId: String,
        queueName: String,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        log(
            actionType: .messageDeleted,
            resource: queueName,
            details: "Message ID: \(messageId)",
            queueManager: queueManager,
            username: username
        )
    }

    /// Log a queue purge operation
    /// - Parameters:
    ///   - queueName: Name of the queue being purged
    ///   - messageCount: Number of messages removed
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func logQueuePurged(
        queueName: String,
        messageCount: Int,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        log(
            actionType: .queuePurged,
            resource: queueName,
            details: "Removed \(messageCount) message\(messageCount == 1 ? "" : "s")",
            queueManager: queueManager,
            username: username
        )
    }

    /// Log a queue deletion
    /// - Parameters:
    ///   - queueName: Name of the queue being deleted
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func logQueueDeleted(
        queueName: String,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        log(
            actionType: .queueDeleted,
            resource: queueName,
            details: nil,
            queueManager: queueManager,
            username: username
        )
    }

    /// Log a queue creation
    /// - Parameters:
    ///   - queueName: Name of the queue being created
    ///   - queueType: Type of queue created
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func logQueueCreated(
        queueName: String,
        queueType: String,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        log(
            actionType: .queueCreated,
            resource: queueName,
            details: "Type: \(queueType)",
            queueManager: queueManager,
            username: username
        )
    }

    /// Log a message send
    /// - Parameters:
    ///   - queueName: Name of the queue receiving the message
    ///   - messageSize: Size of the message in bytes
    ///   - queueManager: Name of the queue manager
    ///   - username: Username performing the action
    public func logMessageSent(
        queueName: String,
        messageSize: Int,
        queueManager: String? = nil,
        username: String? = nil
    ) {
        log(
            actionType: .messageSent,
            resource: queueName,
            details: "Sent message with \(messageSize) bytes",
            queueManager: queueManager,
            username: username
        )
    }

    // MARK: - Private Methods

    /// Output an audit entry to console
    /// - Parameter entry: The entry to output
    private func outputToConsole(_ entry: AuditEntry) {
        let prefix = entry.actionType.isDestructive ? "[AUDIT-DESTRUCTIVE]" : "[AUDIT]"
        let message = "\(prefix) \(entry.logDescription)"

        // Use FileHandle for stderr output (appropriate for audit logs)
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}

// MARK: - Mock AuditService for Testing

/// Mock implementation of AuditServiceProtocol for unit testing
/// Captures logged entries without console output
public final class MockAuditService: AuditServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// In-memory storage for audit entries
    private var entries: [AuditEntry] = []

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Track method calls for verification
    public private(set) var logCallCount: Int = 0
    public private(set) var exportCallCount: Int = 0
    public private(set) var clearCallCount: Int = 0

    /// Whether to simulate export errors
    public var shouldFailOnExport: Bool = false

    public init() {}

    // MARK: - Protocol Implementation

    public func log(_ entry: AuditEntry) {
        lock.lock()
        defer { lock.unlock() }

        logCallCount += 1
        entries.insert(entry, at: 0)
    }

    public func log(
        actionType: AuditEntry.ActionType,
        resource: String,
        details: String?,
        queueManager: String?,
        username: String?
    ) {
        let entry = AuditEntry(
            actionType: actionType,
            resource: resource,
            details: details,
            queueManager: queueManager,
            username: username
        )
        log(entry)
    }

    public func getAuditLog() -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries
    }

    public func getAuditLog(for actionType: AuditEntry.ActionType) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries.filter { $0.actionType == actionType }
    }

    public func getAuditLog(from startDate: Date, to endDate: Date) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }

        return entries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
    }

    public func exportAuditLog(to url: URL) throws {
        lock.lock()
        exportCallCount += 1
        let shouldFail = shouldFailOnExport
        lock.unlock()

        if shouldFail {
            throw NSError(
                domain: "MockAuditService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated export failure"]
            )
        }

        let data = try exportAuditLogAsJSON()
        try data.write(to: url, options: .atomic)
    }

    public func exportAuditLogAsJSON() throws -> Data {
        lock.lock()
        let entriesToExport = entries
        let shouldFail = shouldFailOnExport
        lock.unlock()

        if shouldFail {
            throw NSError(
                domain: "MockAuditService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated export failure"]
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(entriesToExport)
    }

    public func clearAuditLog() {
        lock.lock()
        defer { lock.unlock() }

        clearCallCount += 1
        entries.removeAll()
    }

    public var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return entries.count
    }

    // MARK: - Test Helpers

    /// Reset all tracking counters and entries
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        entries.removeAll()
        logCallCount = 0
        exportCallCount = 0
        clearCallCount = 0
        shouldFailOnExport = false
    }

    /// Get the last logged entry
    public var lastEntry: AuditEntry? {
        lock.lock()
        defer { lock.unlock() }

        return entries.first
    }

    /// Check if a specific action type was logged
    public func hasLogged(actionType: AuditEntry.ActionType) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return entries.contains { $0.actionType == actionType }
    }
}
