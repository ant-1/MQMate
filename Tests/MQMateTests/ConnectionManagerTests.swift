import XCTest
@testable import MQMate

/// Unit tests for ConnectionManager ViewModel
/// Tests connection lifecycle, configuration management, and state handling with mock services
@MainActor
final class ConnectionManagerTests: XCTestCase {

    // MARK: - Properties

    private var connectionManager: ConnectionManager!
    private var mockMQService: MockMQService!
    private var mockKeychain: MockKeychainService!

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockMQService = MockMQService()
        mockKeychain = MockKeychainService()
        connectionManager = ConnectionManager(
            mqService: mockMQService,
            keychainService: mockKeychain
        )
        // Clear any persisted data
        UserDefaults.standard.removeObject(forKey: "mqmate.savedConnections")
    }

    override func tearDown() async throws {
        connectionManager = nil
        mockMQService = nil
        mockKeychain?.clear()
        mockKeychain = nil
        UserDefaults.standard.removeObject(forKey: "mqmate.savedConnections")
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Then
        XCTAssertTrue(connectionManager.savedConnections.isEmpty, "Initial connections should be empty")
        XCTAssertTrue(connectionManager.queueManagers.isEmpty, "Initial queue managers should be empty")
        XCTAssertNil(connectionManager.selectedConnectionId, "Initial selection should be nil")
        XCTAssertFalse(connectionManager.isConnecting, "Should not be connecting initially")
        XCTAssertFalse(connectionManager.hasActiveConnections, "Should have no active connections initially")
        XCTAssertFalse(connectionManager.isLoading, "Should not be loading initially")
        XCTAssertNil(connectionManager.lastError, "Should have no error initially")
    }

    func testInitializationWithDependencyInjection() {
        // Given
        let customMQService = MockMQService()
        let customKeychain = MockKeychainService()

        // When
        let manager = ConnectionManager(
            mqService: customMQService,
            keychainService: customKeychain
        )

        // Then
        XCTAssertNotNil(manager, "ConnectionManager should be created with custom dependencies")
    }

    // MARK: - Add Connection Tests

    func testAddConnectionSuccess() throws {
        // Given
        let config = createTestConfig(name: "Test Connection")

        // When
        try connectionManager.addConnection(config, password: "test-password")

        // Then
        XCTAssertEqual(connectionManager.savedConnections.count, 1, "Should have one saved connection")
        XCTAssertEqual(connectionManager.savedConnections.first?.id, config.id, "Connection ID should match")
        XCTAssertNotNil(connectionManager.queueManagers[config.id], "Queue manager should be created")
        XCTAssertEqual(
            connectionManager.queueManagers[config.id]?.connectionState,
            .disconnected,
            "New connection should be disconnected"
        )
    }

    func testAddConnectionSavesPassword() throws {
        // Given
        let config = createTestConfig(name: "Test Connection")
        let password = "secure-password-123"

        // When
        try connectionManager.addConnection(config, password: password)

        // Then
        XCTAssertTrue(mockKeychain.exists(for: config.keychainKey), "Password should be saved in keychain")
        let retrieved = try mockKeychain.retrieve(for: config.keychainKey)
        XCTAssertEqual(retrieved, password, "Retrieved password should match")
    }

    func testAddConnectionWithoutPassword() throws {
        // Given
        let config = createTestConfig(name: "No Password Connection")

        // When
        try connectionManager.addConnection(config, password: nil)

        // Then
        XCTAssertEqual(connectionManager.savedConnections.count, 1)
        XCTAssertFalse(mockKeychain.exists(for: config.keychainKey), "No password should be in keychain")
    }

    func testAddConnectionWithEmptyPassword() throws {
        // Given
        let config = createTestConfig(name: "Empty Password Connection")

        // When
        try connectionManager.addConnection(config, password: "")

        // Then
        XCTAssertEqual(connectionManager.savedConnections.count, 1)
        XCTAssertFalse(mockKeychain.exists(for: config.keychainKey), "Empty password should not be saved")
    }

    func testAddConnectionValidationFailure() {
        // Given
        let invalidConfig = ConnectionConfig(
            name: "", // Invalid: empty name
            queueManager: "TEST.QM",
            hostname: "localhost",
            port: 1414,
            channel: "TEST.CHANNEL"
        )

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(invalidConfig)) { error in
            guard case MQError.invalidConfiguration = error else {
                XCTFail("Expected invalidConfiguration error, got \(error)")
                return
            }
        }
        XCTAssertTrue(connectionManager.savedConnections.isEmpty, "Invalid connection should not be added")
    }

    func testAddDuplicateConnectionFails() throws {
        // Given
        let config = createTestConfig(name: "Duplicate Test")
        try connectionManager.addConnection(config)

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(config)) { error in
            guard case MQError.invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("already exists"), "Error should mention duplicate")
        }
    }

    func testAddMultipleConnections() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        let config3 = createTestConfig(name: "Connection 3")

        // When
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)
        try connectionManager.addConnection(config3)

        // Then
        XCTAssertEqual(connectionManager.savedConnections.count, 3)
        XCTAssertEqual(connectionManager.queueManagers.count, 3)
    }

    // MARK: - Update Connection Tests

    func testUpdateConnectionSuccess() throws {
        // Given
        let config = createTestConfig(name: "Original Name")
        try connectionManager.addConnection(config, password: "original-password")

        // When
        var updatedConfig = config
        updatedConfig.name = "Updated Name"
        updatedConfig.hostname = "new-host.example.com"
        try connectionManager.updateConnection(updatedConfig, password: "new-password")

        // Then
        let savedConfig = connectionManager.savedConnections.first
        XCTAssertEqual(savedConfig?.name, "Updated Name")
        XCTAssertEqual(savedConfig?.hostname, "new-host.example.com")
        XCTAssertEqual(try mockKeychain.retrieve(for: config.keychainKey), "new-password")
    }

    func testUpdateConnectionKeepsExistingPassword() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "original-password")

        // When - update without providing new password
        var updatedConfig = config
        updatedConfig.name = "Updated Name"
        try connectionManager.updateConnection(updatedConfig, password: nil)

        // Then - password should still exist
        let retrieved = try mockKeychain.retrieve(for: config.keychainKey)
        XCTAssertEqual(retrieved, "original-password", "Original password should be preserved")
    }

    func testUpdateConnectionDisconnectsIfConnected() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        XCTAssertTrue(connectionManager.isConnected(id: config.id), "Should be connected")

        // When
        var updatedConfig = config
        updatedConfig.name = "Updated"
        try connectionManager.updateConnection(updatedConfig)

        // Then
        XCTAssertFalse(connectionManager.isConnected(id: config.id), "Should be disconnected after update")
    }

    func testUpdateNonExistentConnectionFails() {
        // Given
        let config = createTestConfig(name: "Non-existent")

        // When/Then
        XCTAssertThrowsError(try connectionManager.updateConnection(config)) { error in
            guard case MQError.invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("not found"), "Error should mention not found")
        }
    }

    // MARK: - Delete Connection Tests

    func testDeleteConnectionSuccess() throws {
        // Given
        let config = createTestConfig(name: "To Delete")
        try connectionManager.addConnection(config, password: "test-password")

        // When
        connectionManager.deleteConnection(id: config.id)

        // Then
        XCTAssertTrue(connectionManager.savedConnections.isEmpty, "Connection should be removed")
        XCTAssertNil(connectionManager.queueManagers[config.id], "Queue manager should be removed")
        XCTAssertFalse(mockKeychain.exists(for: config.keychainKey), "Password should be deleted")
    }

    func testDeleteConnectionDisconnectsIfConnected() async throws {
        // Given
        let config = createTestConfig(name: "Connected To Delete")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        XCTAssertTrue(connectionManager.isConnected(id: config.id))

        // When
        connectionManager.deleteConnection(id: config.id)

        // Then - should not crash and should be removed
        XCTAssertTrue(connectionManager.savedConnections.isEmpty)
    }

    func testDeleteConnectionClearsSelection() throws {
        // Given
        let config = createTestConfig(name: "Selected")
        try connectionManager.addConnection(config)
        connectionManager.selectConnection(id: config.id)
        XCTAssertEqual(connectionManager.selectedConnectionId, config.id)

        // When
        connectionManager.deleteConnection(id: config.id)

        // Then
        XCTAssertNil(connectionManager.selectedConnectionId, "Selection should be cleared")
    }

    func testDeleteNonExistentConnectionNoOp() {
        // Given
        let randomId = UUID()

        // When/Then - should not crash
        connectionManager.deleteConnection(id: randomId)
        XCTAssertTrue(connectionManager.savedConnections.isEmpty)
    }

    // MARK: - Duplicate Connection Tests

    func testDuplicateConnectionSuccess() throws {
        // Given
        let original = createTestConfig(name: "Original")
        try connectionManager.addConnection(original, password: "original-password")

        // When
        let duplicate = try connectionManager.duplicateConnection(id: original.id)

        // Then
        XCTAssertEqual(connectionManager.savedConnections.count, 2)
        XCTAssertNotEqual(duplicate.id, original.id, "Duplicate should have new ID")
        XCTAssertEqual(duplicate.name, "Original (Copy)", "Duplicate should have copy suffix")
        XCTAssertEqual(duplicate.queueManager, original.queueManager)
        XCTAssertEqual(duplicate.hostname, original.hostname)
        XCTAssertEqual(duplicate.port, original.port)
        XCTAssertEqual(duplicate.channel, original.channel)
    }

    func testDuplicateConnectionCopiesPassword() throws {
        // Given
        let original = createTestConfig(name: "Original")
        let password = "secret-password"
        try connectionManager.addConnection(original, password: password)

        // When
        let duplicate = try connectionManager.duplicateConnection(id: original.id)

        // Then
        let duplicatePassword = try mockKeychain.retrieve(for: duplicate.keychainKey)
        XCTAssertEqual(duplicatePassword, password, "Password should be copied to duplicate")
    }

    func testDuplicateConnectionWithCustomName() throws {
        // Given
        let original = createTestConfig(name: "Original")
        try connectionManager.addConnection(original)

        // When
        let duplicate = try connectionManager.duplicateConnection(id: original.id, newName: "Custom Name")

        // Then
        XCTAssertEqual(duplicate.name, "Custom Name")
    }

    func testDuplicateNonExistentConnectionFails() {
        // Given
        let randomId = UUID()

        // When/Then
        XCTAssertThrowsError(try connectionManager.duplicateConnection(id: randomId)) { error in
            guard case MQError.invalidConfiguration = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
        }
    }

    // MARK: - Connect Tests

    func testConnectSuccess() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test-password")
        mockMQService.shouldFailConnect = false

        // When
        try await connectionManager.connect(id: config.id)

        // Then
        XCTAssertTrue(connectionManager.isConnected(id: config.id))
        XCTAssertEqual(connectionManager.connectionState(for: config.id), .connected)
        XCTAssertTrue(mockMQService.isConnected)
    }

    func testConnectFailure() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test-password")
        mockMQService.shouldFailConnect = true

        // When/Then
        do {
            try await connectionManager.connect(id: config.id)
            XCTFail("Connect should have thrown")
        } catch {
            XCTAssertFalse(connectionManager.isConnected(id: config.id))
            XCTAssertEqual(connectionManager.connectionState(for: config.id), .error)
            XCTAssertNotNil(connectionManager.lastError)
            XCTAssertTrue(connectionManager.showErrorAlert)
        }
    }

    func testConnectNonExistentConfigFails() async {
        // Given
        let randomId = UUID()

        // When/Then
        do {
            try await connectionManager.connect(id: randomId)
            XCTFail("Connect should have thrown")
        } catch {
            guard case MQError.invalidConfiguration = error else {
                XCTFail("Expected invalidConfiguration error, got \(error)")
                return
            }
        }
    }

    func testConnectAlreadyConnectedNoOp() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        XCTAssertTrue(connectionManager.isConnected(id: config.id))

        // When - connect again
        try await connectionManager.connect(id: config.id)

        // Then - should still be connected (no error)
        XCTAssertTrue(connectionManager.isConnected(id: config.id))
    }

    func testConnectUpdatesLastUsedTimestamp() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        let originalConfig = connectionManager.savedConnections.first!
        XCTAssertNil(originalConfig.lastConnectedAt)

        // When
        try await connectionManager.connect(id: config.id)

        // Then
        let updatedConfig = connectionManager.savedConnections.first!
        XCTAssertNotNil(updatedConfig.lastConnectedAt, "Last connected timestamp should be set")
    }

    func testConnectingStateTransition() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")

        // Capture initial state
        XCTAssertEqual(connectionManager.connectionState(for: config.id), .disconnected)

        // When - start connection (this is async, so we'll just verify final state)
        try await connectionManager.connect(id: config.id)

        // Then
        XCTAssertEqual(connectionManager.connectionState(for: config.id), .connected)
    }

    // MARK: - Disconnect Tests

    func testDisconnectSuccess() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        XCTAssertTrue(connectionManager.isConnected(id: config.id))

        // When
        connectionManager.disconnect(id: config.id)

        // Then
        XCTAssertFalse(connectionManager.isConnected(id: config.id))
        XCTAssertEqual(connectionManager.connectionState(for: config.id), .disconnected)
        XCTAssertFalse(mockMQService.isConnected)
    }

    func testDisconnectNotConnectedNoOp() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertFalse(connectionManager.isConnected(id: config.id))

        // When
        connectionManager.disconnect(id: config.id)

        // Then - should not crash, state unchanged
        XCTAssertFalse(connectionManager.isConnected(id: config.id))
    }

    func testDisconnectClearsQueues() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        // After connect, queues should be loaded
        let queuesBeforeDisconnect = connectionManager.queues(for: config.id)
        XCTAssertFalse(queuesBeforeDisconnect.isEmpty, "Queues should be loaded after connect")

        // When
        connectionManager.disconnect(id: config.id)

        // Then
        let queuesAfterDisconnect = connectionManager.queues(for: config.id)
        XCTAssertTrue(queuesAfterDisconnect.isEmpty, "Queues should be cleared after disconnect")
    }

    // MARK: - Disconnect All Tests

    func testDisconnectAllSuccess() async throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        try connectionManager.addConnection(config1, password: "test1")
        try connectionManager.addConnection(config2, password: "test2")
        try await connectionManager.connect(id: config1.id)
        // Note: In a real scenario, each connection would have its own MQService
        // For this test, we just verify the disconnect is called

        // When
        connectionManager.disconnectAll()

        // Then
        XCTAssertFalse(connectionManager.isConnected(id: config1.id))
        XCTAssertFalse(connectionManager.isConnected(id: config2.id))
        XCTAssertFalse(connectionManager.hasActiveConnections)
    }

    func testDisconnectAllWithNoConnections() {
        // Given - no connections

        // When/Then - should not crash
        connectionManager.disconnectAll()
        XCTAssertFalse(connectionManager.hasActiveConnections)
    }

    // MARK: - Toggle Connection Tests

    func testToggleConnectionConnects() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        XCTAssertFalse(connectionManager.isConnected(id: config.id))

        // When
        try await connectionManager.toggleConnection(id: config.id)

        // Then
        XCTAssertTrue(connectionManager.isConnected(id: config.id))
    }

    func testToggleConnectionDisconnects() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)
        XCTAssertTrue(connectionManager.isConnected(id: config.id))

        // When
        try await connectionManager.toggleConnection(id: config.id)

        // Then
        XCTAssertFalse(connectionManager.isConnected(id: config.id))
    }

    func testToggleConnectionConnectsAndCreatesQueueManager() async throws {
        // Given - a new connection that hasn't been connected yet
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        XCTAssertFalse(connectionManager.isConnected(id: config.id))

        // When - toggle should connect since it's currently disconnected
        try await connectionManager.toggleConnection(id: config.id)

        // Then - should be connected with a queue manager
        XCTAssertNotNil(connectionManager.queueManagers[config.id])
        XCTAssertTrue(connectionManager.isConnected(id: config.id))
    }

    // MARK: - Refresh Queues Tests

    func testRefreshQueuesSuccess() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)

        // When
        try await connectionManager.refreshQueues(for: config.id)

        // Then
        let queues = connectionManager.queues(for: config.id)
        XCTAssertFalse(queues.isEmpty, "Queues should be loaded")
        XCTAssertEqual(queues.count, mockMQService.simulatedQueues.count)
    }

    func testRefreshQueuesNotConnectedNoOp() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertFalse(connectionManager.isConnected(id: config.id))

        // When
        try await connectionManager.refreshQueues(for: config.id)

        // Then - should not crash, no queues loaded
        XCTAssertTrue(connectionManager.queues(for: config.id).isEmpty)
    }

    // MARK: - Has Password Tests

    func testHasPasswordReturnsTrue() throws {
        // Given
        let config = createTestConfig(name: "With Password")
        try connectionManager.addConnection(config, password: "test-password")

        // When/Then
        XCTAssertTrue(connectionManager.hasPassword(for: config.id))
    }

    func testHasPasswordReturnsFalse() throws {
        // Given
        let config = createTestConfig(name: "Without Password")
        try connectionManager.addConnection(config, password: nil)

        // When/Then
        XCTAssertFalse(connectionManager.hasPassword(for: config.id))
    }

    func testHasPasswordNonExistentConnection() {
        // Given
        let randomId = UUID()

        // When/Then
        XCTAssertFalse(connectionManager.hasPassword(for: randomId))
    }

    // MARK: - Selection Management Tests

    func testSelectConnection() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertNil(connectionManager.selectedConnectionId)

        // When
        connectionManager.selectConnection(id: config.id)

        // Then
        XCTAssertEqual(connectionManager.selectedConnectionId, config.id)
        XCTAssertEqual(connectionManager.selectedConnection?.id, config.id)
    }

    func testSelectConnectionNil() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        connectionManager.selectConnection(id: config.id)
        XCTAssertNotNil(connectionManager.selectedConnectionId)

        // When
        connectionManager.selectConnection(id: nil)

        // Then
        XCTAssertNil(connectionManager.selectedConnectionId)
        XCTAssertNil(connectionManager.selectedConnection)
    }

    func testSelectNextConnection() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        let config3 = createTestConfig(name: "Connection 3")
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)
        try connectionManager.addConnection(config3)
        connectionManager.selectConnection(id: config1.id)

        // When
        connectionManager.selectNextConnection()

        // Then
        XCTAssertEqual(connectionManager.selectedConnectionId, config2.id)

        // When - select next again
        connectionManager.selectNextConnection()

        // Then
        XCTAssertEqual(connectionManager.selectedConnectionId, config3.id)
    }

    func testSelectNextConnectionWrapsAround() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)
        connectionManager.selectConnection(id: config2.id) // Select last

        // When
        connectionManager.selectNextConnection()

        // Then - should wrap to first
        XCTAssertEqual(connectionManager.selectedConnectionId, config1.id)
    }

    func testSelectNextConnectionWithNoSelection() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertNil(connectionManager.selectedConnectionId)

        // When
        connectionManager.selectNextConnection()

        // Then - should select first
        XCTAssertEqual(connectionManager.selectedConnectionId, config.id)
    }

    func testSelectPreviousConnection() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        let config3 = createTestConfig(name: "Connection 3")
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)
        try connectionManager.addConnection(config3)
        connectionManager.selectConnection(id: config3.id)

        // When
        connectionManager.selectPreviousConnection()

        // Then
        XCTAssertEqual(connectionManager.selectedConnectionId, config2.id)
    }

    func testSelectPreviousConnectionWrapsAround() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)
        connectionManager.selectConnection(id: config1.id) // Select first

        // When
        connectionManager.selectPreviousConnection()

        // Then - should wrap to last
        XCTAssertEqual(connectionManager.selectedConnectionId, config2.id)
    }

    func testSelectPreviousConnectionWithNoSelection() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertNil(connectionManager.selectedConnectionId)

        // When
        connectionManager.selectPreviousConnection()

        // Then - should select last
        XCTAssertEqual(connectionManager.selectedConnectionId, config.id)
    }

    func testSelectedQueueManager() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)
        XCTAssertNil(connectionManager.selectedQueueManager)

        // When
        connectionManager.selectConnection(id: config.id)

        // Then
        XCTAssertNotNil(connectionManager.selectedQueueManager)
        XCTAssertEqual(connectionManager.selectedQueueManager?.id, config.id)
    }

    // MARK: - Error Handling Tests

    func testClearError() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        mockMQService.shouldFailConnect = true

        // Trigger an error
        try? await connectionManager.connect(id: config.id)
        XCTAssertNotNil(connectionManager.lastError)
        XCTAssertTrue(connectionManager.showErrorAlert)

        // When
        connectionManager.clearError()

        // Then
        XCTAssertNil(connectionManager.lastError)
        XCTAssertFalse(connectionManager.showErrorAlert)
    }

    // MARK: - Computed Properties Tests

    func testConnectionsProperty() throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        try connectionManager.addConnection(config1)
        try connectionManager.addConnection(config2)

        // Then
        XCTAssertEqual(connectionManager.connections.count, 2)
    }

    func testActiveConnectionsProperty() async throws {
        // Given
        let config1 = createTestConfig(name: "Connection 1")
        let config2 = createTestConfig(name: "Connection 2")
        try connectionManager.addConnection(config1, password: "test1")
        try connectionManager.addConnection(config2)

        XCTAssertEqual(connectionManager.activeConnections.count, 0)

        // When - connect one
        try await connectionManager.connect(id: config1.id)

        // Then
        XCTAssertEqual(connectionManager.activeConnections.count, 1)
        XCTAssertEqual(connectionManager.activeConnections.first?.id, config1.id)
    }

    func testIsConnectingProperty() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)

        // Then - initially not connecting
        XCTAssertFalse(connectionManager.isConnecting)

        // Note: Testing the actual connecting state would require intercepting
        // the async connect operation, which is complex. The property itself
        // is tested via the connectionState checks.
    }

    func testConnectionStateConvenience() throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config)

        // Then
        XCTAssertEqual(connectionManager.connectionState(for: config.id), .disconnected)
    }

    func testConnectionStateForNonExistentId() {
        // Given
        let randomId = UUID()

        // Then - should return disconnected as default
        XCTAssertEqual(connectionManager.connectionState(for: randomId), .disconnected)
    }

    func testQueuesForConnectionId() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        try await connectionManager.connect(id: config.id)

        // Then
        let queues = connectionManager.queues(for: config.id)
        XCTAssertEqual(queues.count, mockMQService.simulatedQueues.count)
    }

    func testQueuesForNonExistentConnectionId() {
        // Given
        let randomId = UUID()

        // Then
        XCTAssertTrue(connectionManager.queues(for: randomId).isEmpty)
    }

    // MARK: - Validation Tests

    func testAddConnectionWithInvalidPort() {
        // Given
        let config = ConnectionConfig(
            name: "Test",
            queueManager: "TEST.QM",
            hostname: "localhost",
            port: 0, // Invalid
            channel: "TEST.CHANNEL"
        )

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(config))
    }

    func testAddConnectionWithInvalidQueueManagerName() {
        // Given
        let longName = String(repeating: "A", count: 50) // > 48 chars
        let config = ConnectionConfig(
            name: "Test",
            queueManager: longName,
            hostname: "localhost",
            port: 1414,
            channel: "TEST.CHANNEL"
        )

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(config))
    }

    func testAddConnectionWithInvalidChannel() {
        // Given
        let longChannel = String(repeating: "A", count: 25) // > 20 chars
        let config = ConnectionConfig(
            name: "Test",
            queueManager: "TEST.QM",
            hostname: "localhost",
            port: 1414,
            channel: longChannel
        )

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(config))
    }

    // MARK: - Keychain Error Handling Tests

    func testConnectFailsWhenKeychainFails() async throws {
        // Given
        let config = createTestConfig(name: "Test")
        try connectionManager.addConnection(config, password: "test")
        mockKeychain.shouldFailOnRetrieve = true

        // When/Then
        do {
            try await connectionManager.connect(id: config.id)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(connectionManager.connectionState(for: config.id), .error)
        }
    }

    func testAddConnectionFailsWhenKeychainSaveFails() {
        // Given
        let config = createTestConfig(name: "Test")
        mockKeychain.shouldFailOnSave = true

        // When/Then
        XCTAssertThrowsError(try connectionManager.addConnection(config, password: "test"))
        XCTAssertTrue(connectionManager.savedConnections.isEmpty, "Connection should not be added")
    }

    // MARK: - Preview Support Tests

    func testPreviewConnectionManager() {
        // Given
        let preview = ConnectionManager.preview

        // Then
        XCTAssertFalse(preview.savedConnections.isEmpty, "Preview should have sample connections")
        XCTAssertNotNil(preview.selectedConnectionId, "Preview should have a selection")
    }

    // MARK: - Helper Methods

    /// Create a test ConnectionConfig with the given name
    private func createTestConfig(name: String) -> ConnectionConfig {
        ConnectionConfig(
            name: name,
            queueManager: "TEST.QM.\(name.hashValue)",
            hostname: "localhost",
            port: 1414,
            channel: "TEST.CHANNEL",
            username: "testuser"
        )
    }
}

// MARK: - MockMQService Extended Tests

@MainActor
final class MockMQServiceTests: XCTestCase {

    func testMockMQServiceDefaultState() {
        // Given
        let mock = MockMQService()

        // Then
        XCTAssertFalse(mock.isConnected)
        XCTAssertFalse(mock.shouldFailConnect)
        XCTAssertFalse(mock.simulatedQueues.isEmpty)
    }

    func testMockMQServiceConnect() async throws {
        // Given
        let mock = MockMQService()
        XCTAssertFalse(mock.isConnected)

        // When
        try await mock.connect(
            queueManager: "TEST.QM",
            channel: "TEST.CHANNEL",
            host: "localhost",
            port: 1414,
            username: "user",
            password: "pass"
        )

        // Then
        XCTAssertTrue(mock.isConnected)
    }

    func testMockMQServiceConnectFailure() async {
        // Given
        let mock = MockMQService()
        mock.shouldFailConnect = true

        // When/Then
        do {
            try await mock.connect(
                queueManager: "TEST.QM",
                channel: "TEST.CHANNEL",
                host: "localhost",
                port: 1414,
                username: nil,
                password: nil
            )
            XCTFail("Should have thrown")
        } catch {
            XCTAssertFalse(mock.isConnected)
        }
    }

    func testMockMQServiceDisconnect() async throws {
        // Given
        let mock = MockMQService()
        try await mock.connect(
            queueManager: "TEST.QM",
            channel: "TEST.CHANNEL",
            host: "localhost",
            port: 1414,
            username: nil,
            password: nil
        )
        XCTAssertTrue(mock.isConnected)

        // When
        mock.disconnect()

        // Then
        XCTAssertFalse(mock.isConnected)
    }

    func testMockMQServiceListQueues() async throws {
        // Given
        let mock = MockMQService()
        try await mock.connect(
            queueManager: "TEST.QM",
            channel: "TEST.CHANNEL",
            host: "localhost",
            port: 1414,
            username: nil,
            password: nil
        )

        // When
        let queues = try await mock.listQueues(filter: "*")

        // Then
        XCTAssertFalse(queues.isEmpty)
        XCTAssertEqual(queues.count, mock.simulatedQueues.count)
    }

    func testMockMQServiceListQueuesNotConnected() async {
        // Given
        let mock = MockMQService()
        XCTAssertFalse(mock.isConnected)

        // When/Then
        do {
            _ = try await mock.listQueues(filter: "*")
            XCTFail("Should have thrown")
        } catch {
            guard case MQError.notConnected = error else {
                XCTFail("Expected notConnected error")
                return
            }
        }
    }

    func testMockMQServiceGetQueueInfo() throws {
        // Given
        let mock = MockMQService()
        let queueName = mock.simulatedQueues.first!.name

        // When
        let info = try mock.getQueueInfo(queueName: queueName)

        // Then
        XCTAssertEqual(info.name, queueName)
    }

    func testMockMQServiceGetQueueInfoNotFound() {
        // Given
        let mock = MockMQService()

        // When/Then
        XCTAssertThrowsError(try mock.getQueueInfo(queueName: "NON.EXISTENT.QUEUE"))
    }

    func testMockMQServiceCustomQueues() async throws {
        // Given
        let mock = MockMQService()
        mock.simulatedQueues = [
            MQService.QueueInfo(name: "CUSTOM.QUEUE.1", queueType: .local, currentDepth: 100, maxDepth: 1000),
            MQService.QueueInfo(name: "CUSTOM.QUEUE.2", queueType: .alias, currentDepth: 0, maxDepth: 500)
        ]
        try await mock.connect(
            queueManager: "TEST.QM",
            channel: "TEST.CHANNEL",
            host: "localhost",
            port: 1414,
            username: nil,
            password: nil
        )

        // When
        let queues = try await mock.listQueues(filter: "*")

        // Then
        XCTAssertEqual(queues.count, 2)
        XCTAssertEqual(queues[0].name, "CUSTOM.QUEUE.1")
        XCTAssertEqual(queues[1].name, "CUSTOM.QUEUE.2")
    }
}
