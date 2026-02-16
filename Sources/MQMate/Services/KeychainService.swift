import Foundation
import Security

// MARK: - KeychainService Protocol

/// Protocol defining Keychain operations for credential storage
public protocol KeychainServiceProtocol: Sendable {
    /// Save a password to the Keychain
    /// - Parameters:
    ///   - password: The password to store
    ///   - account: The account identifier (typically connection ID)
    func save(password: String, for account: String) throws

    /// Retrieve a password from the Keychain
    /// - Parameter account: The account identifier
    /// - Returns: The stored password, or nil if not found
    func retrieve(for account: String) throws -> String?

    /// Delete a password from the Keychain
    /// - Parameter account: The account identifier
    func delete(for account: String) throws

    /// Check if a password exists for the given account
    /// - Parameter account: The account identifier
    /// - Returns: True if a password is stored for this account
    func exists(for account: String) -> Bool
}

// MARK: - KeychainService Implementation

/// Service for securely storing and retrieving credentials using macOS Keychain
/// Uses the Security framework's kSecClassGenericPassword for credential storage
public final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// Service identifier for all MQMate credentials in Keychain
    /// This groups all credentials under a single service name
    public let service: String

    /// Optional access group for sharing credentials between apps
    /// Set to nil for single-app usage
    private let accessGroup: String?

    /// Serial queue for thread-safe Keychain operations
    private let queue = DispatchQueue(label: "com.mqmate.keychain", qos: .userInitiated)

    // MARK: - Initialization

    /// Create a new KeychainService instance
    /// - Parameters:
    ///   - service: Service identifier for Keychain entries (default: "com.mqmate.credentials")
    ///   - accessGroup: Optional access group for sharing between apps
    public init(service: String = "com.mqmate.credentials", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods

    /// Save a password to the Keychain
    /// If a password already exists for the account, it will be updated
    /// - Parameters:
    ///   - password: The password to store
    ///   - account: The account identifier (typically the connection's keychainKey)
    /// - Throws: MQError.keychainSaveFailed if the operation fails
    public func save(password: String, for account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw MQError.keychainSaveFailed(status: errSecParam)
        }

        // Build the query for adding the item
        var query = baseQuery(for: account)
        query[kSecValueData as String] = passwordData
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        // Attempt to add the item
        var status = SecItemAdd(query as CFDictionary, nil)

        // If the item already exists, update it instead
        if status == errSecDuplicateItem {
            let searchQuery = baseQuery(for: account)
            let updateAttributes: [String: Any] = [
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw MQError.keychainSaveFailed(status: status)
        }
    }

    /// Retrieve a password from the Keychain
    /// - Parameter account: The account identifier
    /// - Returns: The stored password, or nil if not found
    /// - Throws: MQError.keychainRetrieveFailed if an error occurs (other than item not found)
    public func retrieve(for account: String) throws -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                return nil
            }
            return password

        case errSecItemNotFound:
            // Item not found is not an error - just return nil
            return nil

        default:
            throw MQError.keychainRetrieveFailed(status: status)
        }
    }

    /// Delete a password from the Keychain
    /// - Parameter account: The account identifier
    /// - Throws: MQError.keychainDeleteFailed if the operation fails (does not throw if item doesn't exist)
    public func delete(for account: String) throws {
        let query = baseQuery(for: account)
        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is acceptable - the item is already gone
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MQError.keychainDeleteFailed(status: status)
        }
    }

    /// Check if a password exists for the given account
    /// - Parameter account: The account identifier
    /// - Returns: True if a password is stored for this account
    public func exists(for account: String) -> Bool {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all MQMate credentials from the Keychain
    /// Use with caution - this removes all stored passwords
    /// - Throws: MQError.keychainDeleteFailed if the operation fails
    public func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is acceptable - nothing to delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MQError.keychainDeleteFailed(status: status)
        }
    }

    // MARK: - Convenience Methods for ConnectionConfig

    /// Save a password for a ConnectionConfig
    /// - Parameters:
    ///   - password: The password to store
    ///   - config: The ConnectionConfig whose keychainKey will be used
    /// - Throws: MQError.keychainSaveFailed if the operation fails
    public func save(password: String, for config: ConnectionConfig) throws {
        try save(password: password, for: config.keychainKey)
    }

    /// Retrieve a password for a ConnectionConfig
    /// - Parameter config: The ConnectionConfig whose keychainKey will be used
    /// - Returns: The stored password, or nil if not found
    /// - Throws: MQError.keychainRetrieveFailed if an error occurs
    public func retrieve(for config: ConnectionConfig) throws -> String? {
        try retrieve(for: config.keychainKey)
    }

    /// Delete a password for a ConnectionConfig
    /// - Parameter config: The ConnectionConfig whose keychainKey will be used
    /// - Throws: MQError.keychainDeleteFailed if the operation fails
    public func delete(for config: ConnectionConfig) throws {
        try delete(for: config.keychainKey)
    }

    /// Check if a password exists for a ConnectionConfig
    /// - Parameter config: The ConnectionConfig to check
    /// - Returns: True if a password is stored for this config
    public func exists(for config: ConnectionConfig) -> Bool {
        exists(for: config.keychainKey)
    }

    // MARK: - Private Methods

    /// Build the base query dictionary for Keychain operations
    /// - Parameter account: The account identifier
    /// - Returns: Dictionary with common query parameters
    private func baseQuery(for account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - KeychainService Error Descriptions

extension MQError {
    /// Get a human-readable description for a Keychain OSStatus error
    /// - Parameter status: The OSStatus from a Security framework call
    /// - Returns: A user-friendly description of the error
    public static func keychainErrorDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Operation completed successfully"
        case errSecItemNotFound:
            return "The specified item could not be found"
        case errSecDuplicateItem:
            return "The specified item already exists"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction is not allowed"
        case errSecDecode:
            return "Unable to decode the provided data"
        case errSecParam:
            return "One or more parameters passed were invalid"
        case errSecAllocate:
            return "Failed to allocate memory"
        case errSecNotAvailable:
            return "Keychain is not available"
        case errSecDiskFull:
            return "Disk is full"
        case errSecIO:
            return "I/O error occurred"
        case errSecOpWr:
            return "File is already open with write permission"
        case errSecWrPerm:
            return "Write permissions error"
        case errSecReadOnly:
            return "Keychain is read-only"
        case errSecNoSuchKeychain:
            return "The specified keychain could not be found"
        case errSecInvalidKeychain:
            return "The specified keychain is invalid"
        case errSecNoSuchAttr:
            return "The specified attribute does not exist"
        case errSecMissingEntitlement:
            return "Missing required entitlement"
        case errSecUserCanceled:
            return "User canceled the operation"
        default:
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Unknown Keychain error (OSStatus: \(status))"
        }
    }
}

// MARK: - Mock KeychainService for Testing

/// Mock implementation of KeychainServiceProtocol for unit testing
/// Stores credentials in memory instead of the actual Keychain
public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {

    /// In-memory storage for passwords
    private var storage: [String: String] = [:]

    /// Lock for thread-safe access to storage
    private let lock = NSLock()

    /// Whether to simulate errors
    public var shouldFailOnSave: Bool = false
    public var shouldFailOnRetrieve: Bool = false
    public var shouldFailOnDelete: Bool = false
    public var simulatedErrorStatus: OSStatus = errSecAuthFailed

    public init() {}

    public func save(password: String, for account: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if shouldFailOnSave {
            throw MQError.keychainSaveFailed(status: simulatedErrorStatus)
        }

        storage[account] = password
    }

    public func retrieve(for account: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        if shouldFailOnRetrieve {
            throw MQError.keychainRetrieveFailed(status: simulatedErrorStatus)
        }

        return storage[account]
    }

    public func delete(for account: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if shouldFailOnDelete {
            throw MQError.keychainDeleteFailed(status: simulatedErrorStatus)
        }

        storage.removeValue(forKey: account)
    }

    public func exists(for account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return storage[account] != nil
    }

    /// Clear all stored credentials (for test cleanup)
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        storage.removeAll()
    }

    /// Get the count of stored credentials
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }

        return storage.count
    }
}
