import XCTest
@testable import MQMate

/// Unit tests for KeychainService and MockKeychainService
final class KeychainServiceTests: XCTestCase {

    // MARK: - Properties

    private var mockKeychain: MockKeychainService!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
    }

    override func tearDown() {
        mockKeychain.clear()
        mockKeychain = nil
        super.tearDown()
    }

    // MARK: - MockKeychainService Basic CRUD Tests

    func testSaveAndRetrievePassword() throws {
        // Given
        let account = "test-account-1"
        let password = "test-password-123"

        // When
        try mockKeychain.save(password: password, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, password, "Retrieved password should match saved password")
    }

    func testRetrieveNonExistentPassword() throws {
        // Given
        let account = "non-existent-account"

        // When
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertNil(retrieved, "Should return nil for non-existent account")
    }

    func testSaveOverwritesExistingPassword() throws {
        // Given
        let account = "test-account-2"
        let originalPassword = "original-password"
        let newPassword = "new-password"

        // When
        try mockKeychain.save(password: originalPassword, for: account)
        try mockKeychain.save(password: newPassword, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, newPassword, "Password should be updated to the new value")
    }

    func testDeletePassword() throws {
        // Given
        let account = "test-account-3"
        let password = "password-to-delete"

        // When
        try mockKeychain.save(password: password, for: account)
        try mockKeychain.delete(for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertNil(retrieved, "Password should be nil after deletion")
    }

    func testDeleteNonExistentPassword() throws {
        // Given
        let account = "never-existed"

        // When/Then - Should not throw
        XCTAssertNoThrow(try mockKeychain.delete(for: account), "Deleting non-existent password should not throw")
    }

    func testExistsReturnsTrueForStoredPassword() throws {
        // Given
        let account = "test-account-4"
        let password = "test-password"

        // When
        try mockKeychain.save(password: password, for: account)

        // Then
        XCTAssertTrue(mockKeychain.exists(for: account), "exists should return true for stored password")
    }

    func testExistsReturnsFalseForNonExistentPassword() {
        // Given
        let account = "non-existent-account"

        // Then
        XCTAssertFalse(mockKeychain.exists(for: account), "exists should return false for non-existent password")
    }

    func testExistsReturnsFalseAfterDeletion() throws {
        // Given
        let account = "test-account-5"
        let password = "test-password"

        // When
        try mockKeychain.save(password: password, for: account)
        try mockKeychain.delete(for: account)

        // Then
        XCTAssertFalse(mockKeychain.exists(for: account), "exists should return false after deletion")
    }

    func testClearRemovesAllPasswords() throws {
        // Given
        try mockKeychain.save(password: "password1", for: "account1")
        try mockKeychain.save(password: "password2", for: "account2")
        try mockKeychain.save(password: "password3", for: "account3")

        // When
        mockKeychain.clear()

        // Then
        XCTAssertEqual(mockKeychain.count, 0, "Count should be 0 after clear")
        XCTAssertFalse(mockKeychain.exists(for: "account1"))
        XCTAssertFalse(mockKeychain.exists(for: "account2"))
        XCTAssertFalse(mockKeychain.exists(for: "account3"))
    }

    func testCountReturnsCorrectNumber() throws {
        // Given
        XCTAssertEqual(mockKeychain.count, 0, "Initial count should be 0")

        // When
        try mockKeychain.save(password: "password1", for: "account1")
        try mockKeychain.save(password: "password2", for: "account2")

        // Then
        XCTAssertEqual(mockKeychain.count, 2, "Count should be 2 after saving 2 passwords")
    }

    // MARK: - MockKeychainService Error Simulation Tests

    func testSaveFailsWhenSimulatedError() {
        // Given
        mockKeychain.shouldFailOnSave = true
        mockKeychain.simulatedErrorStatus = -25293 // errSecAuthFailed

        // When/Then
        XCTAssertThrowsError(try mockKeychain.save(password: "test", for: "account")) { error in
            guard case MQError.keychainSaveFailed(let status) = error else {
                XCTFail("Expected keychainSaveFailed error")
                return
            }
            XCTAssertEqual(status, -25293, "Error status should match simulated status")
        }
    }

    func testRetrieveFailsWhenSimulatedError() throws {
        // Given
        try mockKeychain.save(password: "test", for: "account")
        mockKeychain.shouldFailOnRetrieve = true
        mockKeychain.simulatedErrorStatus = -25293

        // When/Then
        XCTAssertThrowsError(try mockKeychain.retrieve(for: "account")) { error in
            guard case MQError.keychainRetrieveFailed(let status) = error else {
                XCTFail("Expected keychainRetrieveFailed error")
                return
            }
            XCTAssertEqual(status, -25293)
        }
    }

    func testDeleteFailsWhenSimulatedError() throws {
        // Given
        try mockKeychain.save(password: "test", for: "account")
        mockKeychain.shouldFailOnDelete = true
        mockKeychain.simulatedErrorStatus = -25293

        // When/Then
        XCTAssertThrowsError(try mockKeychain.delete(for: "account")) { error in
            guard case MQError.keychainDeleteFailed(let status) = error else {
                XCTFail("Expected keychainDeleteFailed error")
                return
            }
            XCTAssertEqual(status, -25293)
        }
    }

    func testErrorFlagsCanBeToggled() throws {
        // Given
        mockKeychain.shouldFailOnSave = true

        // Verify it throws
        XCTAssertThrowsError(try mockKeychain.save(password: "test", for: "account"))

        // When - disable the flag
        mockKeychain.shouldFailOnSave = false

        // Then - should succeed
        XCTAssertNoThrow(try mockKeychain.save(password: "test", for: "account"))
    }

    // MARK: - MockKeychainService ConnectionConfig Convenience Tests

    func testSaveAndRetrieveWithConnectionConfig() throws {
        // Given
        let config = ConnectionConfig.sample
        let password = "config-password-123"

        // Create a mock keychain with same interface as real service
        let keychain = mockKeychain as KeychainServiceProtocol

        // When
        try keychain.save(password: password, for: config.keychainKey)
        let retrieved = try keychain.retrieve(for: config.keychainKey)

        // Then
        XCTAssertEqual(retrieved, password)
    }

    func testDeleteWithConnectionConfig() throws {
        // Given
        let config = ConnectionConfig.sample
        let password = "config-password"

        // When
        try mockKeychain.save(password: password, for: config.keychainKey)
        try mockKeychain.delete(for: config.keychainKey)

        // Then
        XCTAssertFalse(mockKeychain.exists(for: config.keychainKey))
    }

    func testExistsWithConnectionConfig() throws {
        // Given
        let config = ConnectionConfig.sample

        // When - before saving
        XCTAssertFalse(mockKeychain.exists(for: config.keychainKey))

        // Save
        try mockKeychain.save(password: "test", for: config.keychainKey)

        // Then
        XCTAssertTrue(mockKeychain.exists(for: config.keychainKey))
    }

    // MARK: - Multiple Accounts Tests

    func testMultipleAccountsAreIsolated() throws {
        // Given
        let account1 = "account-1"
        let account2 = "account-2"
        let password1 = "password-for-account-1"
        let password2 = "password-for-account-2"

        // When
        try mockKeychain.save(password: password1, for: account1)
        try mockKeychain.save(password: password2, for: account2)

        // Then
        XCTAssertEqual(try mockKeychain.retrieve(for: account1), password1)
        XCTAssertEqual(try mockKeychain.retrieve(for: account2), password2)

        // When - delete one
        try mockKeychain.delete(for: account1)

        // Then - other is still there
        XCTAssertNil(try mockKeychain.retrieve(for: account1))
        XCTAssertEqual(try mockKeychain.retrieve(for: account2), password2)
    }

    // MARK: - Edge Cases Tests

    func testSaveEmptyPassword() throws {
        // Given
        let account = "account-empty-password"
        let emptyPassword = ""

        // When
        try mockKeychain.save(password: emptyPassword, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, emptyPassword, "Empty password should be stored and retrieved")
    }

    func testSavePasswordWithSpecialCharacters() throws {
        // Given
        let account = "account-special"
        let specialPassword = "p@$$w0rd!#%^&*()_+-=[]{}|;':\",./<>?"

        // When
        try mockKeychain.save(password: specialPassword, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, specialPassword, "Password with special characters should be handled correctly")
    }

    func testSavePasswordWithUnicodeCharacters() throws {
        // Given
        let account = "account-unicode"
        let unicodePassword = "密码🔐пароль"

        // When
        try mockKeychain.save(password: unicodePassword, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, unicodePassword, "Password with unicode characters should be handled correctly")
    }

    func testAccountWithSpecialCharacters() throws {
        // Given
        let specialAccount = "user@domain.com/queue.manager"
        let password = "test-password"

        // When
        try mockKeychain.save(password: password, for: specialAccount)
        let retrieved = try mockKeychain.retrieve(for: specialAccount)

        // Then
        XCTAssertEqual(retrieved, password, "Account with special characters should work correctly")
    }

    func testLongPassword() throws {
        // Given
        let account = "account-long-password"
        let longPassword = String(repeating: "a", count: 10000) // 10KB password

        // When
        try mockKeychain.save(password: longPassword, for: account)
        let retrieved = try mockKeychain.retrieve(for: account)

        // Then
        XCTAssertEqual(retrieved, longPassword, "Long password should be stored and retrieved correctly")
    }

    // MARK: - KeychainService Protocol Conformance Tests

    func testMockKeychainConformsToProtocol() {
        // Given
        let keychain: KeychainServiceProtocol = mockKeychain

        // Then - This compiles, proving conformance
        XCTAssertNotNil(keychain, "MockKeychainService should conform to KeychainServiceProtocol")
    }

    func testRealKeychainServiceConformsToProtocol() {
        // Given
        let keychain: KeychainServiceProtocol = KeychainService(service: "com.mqmate.tests")

        // Then
        XCTAssertNotNil(keychain, "KeychainService should conform to KeychainServiceProtocol")
    }

    // MARK: - MQError Keychain Error Description Tests

    func testKeychainSaveFailedErrorDescription() {
        // Given
        let error = MQError.keychainSaveFailed(status: -25293)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("save") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("-25293") ?? false)
    }

    func testKeychainRetrieveFailedErrorDescription() {
        // Given
        let error = MQError.keychainRetrieveFailed(status: -25300)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("retrieve") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("-25300") ?? false)
    }

    func testKeychainDeleteFailedErrorDescription() {
        // Given
        let error = MQError.keychainDeleteFailed(status: -25299)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("delete") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("-25299") ?? false)
    }

    func testKeychainErrorDescriptionForCommonStatuses() {
        // Test common OSStatus values
        let testCases: [(OSStatus, String)] = [
            (0, "success"),       // errSecSuccess
            (-25300, "not be found"), // errSecItemNotFound
            (-25299, "already exists"), // errSecDuplicateItem
            (-25293, "Authentication"), // errSecAuthFailed
        ]

        for (status, expectedSubstring) in testCases {
            let description = MQError.keychainErrorDescription(status)
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Description for status \(status) should contain '\(expectedSubstring)', got: \(description)"
            )
        }
    }

    func testKeychainErrorDescriptionForUnknownStatus() {
        // Given
        let unknownStatus: OSStatus = -99999

        // When
        let description = MQError.keychainErrorDescription(unknownStatus)

        // Then
        XCTAssertTrue(description.contains("-99999") || description.contains("99999"),
                     "Unknown status description should include the status code")
    }

    // MARK: - KeychainService Initialization Tests

    func testKeychainServiceDefaultInitialization() {
        // Given
        let keychain = KeychainService()

        // Then
        XCTAssertEqual(keychain.service, "com.mqmate.credentials")
    }

    func testKeychainServiceCustomServiceInitialization() {
        // Given
        let customService = "com.example.test"
        let keychain = KeychainService(service: customService)

        // Then
        XCTAssertEqual(keychain.service, customService)
    }

    // MARK: - Recovery Suggestion Tests

    func testKeychainErrorsHaveRecoverySuggestion() {
        // Given
        let errors: [MQError] = [
            .keychainSaveFailed(status: -25293),
            .keychainRetrieveFailed(status: -25300),
            .keychainDeleteFailed(status: -25299)
        ]

        // Then
        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion,
                          "Keychain error should have recovery suggestion")
            XCTAssertTrue(error.recoverySuggestion?.contains("Keychain") ?? false,
                         "Recovery suggestion should mention Keychain")
        }
    }

    // MARK: - Equatable Tests

    func testMQErrorEquatableForKeychainErrors() {
        // Given
        let error1 = MQError.keychainSaveFailed(status: -25293)
        let error2 = MQError.keychainSaveFailed(status: -25293)
        let error3 = MQError.keychainSaveFailed(status: -25300)

        // Then
        XCTAssertEqual(error1, error2, "Same keychain errors should be equal")
        XCTAssertNotEqual(error1, error3, "Different status codes should not be equal")
    }

    // MARK: - Thread Safety Tests

    func testMockKeychainThreadSafety() async throws {
        // Given
        let iterations = 100

        // When - Perform concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let account = "concurrent-account-\(i % 10)"
                    let password = "password-\(i)"

                    try? self.mockKeychain.save(password: password, for: account)
                    _ = try? self.mockKeychain.retrieve(for: account)
                    _ = self.mockKeychain.exists(for: account)
                }
            }
        }

        // Then - Should complete without crashes
        // If we got here without deadlock or crash, the test passes
        XCTAssertTrue(true, "Concurrent operations completed without deadlock")
    }
}
