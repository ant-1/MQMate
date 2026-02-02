import XCTest
@testable import MQMate

/// Unit tests for data models: Queue, QueueManager, and Message
final class ModelTests: XCTestCase {

    // MARK: - Queue Tests

    func testQueueInitialization() {
        // Given/When
        let queue = Queue(
            name: "TEST.QUEUE",
            queueType: .local,
            depth: 100,
            maxDepth: 5000,
            queueDescription: "Test queue description",
            getInhibited: false,
            putInhibited: false,
            openInputCount: 2,
            openOutputCount: 3
        )

        // Then
        XCTAssertEqual(queue.id, "TEST.QUEUE", "ID should match queue name")
        XCTAssertEqual(queue.name, "TEST.QUEUE")
        XCTAssertEqual(queue.queueType, .local)
        XCTAssertEqual(queue.depth, 100)
        XCTAssertEqual(queue.maxDepth, 5000)
        XCTAssertEqual(queue.queueDescription, "Test queue description")
        XCTAssertFalse(queue.getInhibited)
        XCTAssertFalse(queue.putInhibited)
        XCTAssertEqual(queue.openInputCount, 2)
        XCTAssertEqual(queue.openOutputCount, 3)
        XCTAssertNotNil(queue.lastRefreshedAt)
    }

    func testQueueDefaultValues() {
        // Given/When
        let queue = Queue(name: "MINIMAL.QUEUE")

        // Then
        XCTAssertEqual(queue.queueType, .local, "Default queue type should be local")
        XCTAssertEqual(queue.depth, 0, "Default depth should be 0")
        XCTAssertEqual(queue.maxDepth, 5000, "Default maxDepth should be 5000")
        XCTAssertNil(queue.queueDescription, "Default description should be nil")
        XCTAssertFalse(queue.getInhibited)
        XCTAssertFalse(queue.putInhibited)
        XCTAssertEqual(queue.openInputCount, 0)
        XCTAssertEqual(queue.openOutputCount, 0)
    }

    // MARK: - Queue Computed Properties Tests

    func testQueueDepthPercentage() {
        // Given
        let halfFullQueue = Queue(name: "Q1", depth: 2500, maxDepth: 5000)
        let emptyQueue = Queue(name: "Q2", depth: 0, maxDepth: 5000)
        let fullQueue = Queue(name: "Q3", depth: 5000, maxDepth: 5000)
        let zeroMaxQueue = Queue(name: "Q4", depth: 100, maxDepth: 0)

        // Then
        XCTAssertEqual(halfFullQueue.depthPercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(emptyQueue.depthPercentage, 0.0, accuracy: 0.001)
        XCTAssertEqual(fullQueue.depthPercentage, 1.0, accuracy: 0.001)
        XCTAssertEqual(zeroMaxQueue.depthPercentage, 0.0, "Zero maxDepth should return 0")
    }

    func testQueueDepthPercentageFormatted() {
        // Given
        let queue = Queue(name: "Q1", depth: 4200, maxDepth: 5000)
        let zeroMaxQueue = Queue(name: "Q2", depth: 100, maxDepth: 0)

        // Then
        XCTAssertEqual(queue.depthPercentageFormatted, "84%")
        XCTAssertEqual(zeroMaxQueue.depthPercentageFormatted, "N/A")
    }

    func testQueueCapacityThresholds() {
        // Given
        let normalQueue = Queue(name: "Q1", depth: 2000, maxDepth: 5000) // 40%
        let nearCapacityQueue = Queue(name: "Q2", depth: 4100, maxDepth: 5000) // 82%
        let criticalQueue = Queue(name: "Q3", depth: 4800, maxDepth: 5000) // 96%
        let fullQueue = Queue(name: "Q4", depth: 5000, maxDepth: 5000) // 100%

        // Then - isNearCapacity (> 80%)
        XCTAssertFalse(normalQueue.isNearCapacity)
        XCTAssertTrue(nearCapacityQueue.isNearCapacity)
        XCTAssertTrue(criticalQueue.isNearCapacity)
        XCTAssertTrue(fullQueue.isNearCapacity)

        // Then - isCriticalCapacity (> 95%)
        XCTAssertFalse(normalQueue.isCriticalCapacity)
        XCTAssertFalse(nearCapacityQueue.isCriticalCapacity)
        XCTAssertTrue(criticalQueue.isCriticalCapacity)
        XCTAssertTrue(fullQueue.isCriticalCapacity)

        // Then - isFull
        XCTAssertFalse(normalQueue.isFull)
        XCTAssertFalse(nearCapacityQueue.isFull)
        XCTAssertFalse(criticalQueue.isFull)
        XCTAssertTrue(fullQueue.isFull)
    }

    func testQueueEmptyAndHasMessages() {
        // Given
        let emptyQueue = Queue(name: "Q1", depth: 0)
        let queueWithMessages = Queue(name: "Q2", depth: 10)

        // Then
        XCTAssertTrue(emptyQueue.isEmpty)
        XCTAssertFalse(emptyQueue.hasMessages)
        XCTAssertFalse(queueWithMessages.isEmpty)
        XCTAssertTrue(queueWithMessages.hasMessages)
    }

    func testQueueCanPutAndCanGet() {
        // Given
        let normalQueue = Queue(name: "Q1", depth: 100, maxDepth: 5000)
        let putInhibitedQueue = Queue(name: "Q2", depth: 100, maxDepth: 5000, putInhibited: true)
        let getInhibitedQueue = Queue(name: "Q3", depth: 100, maxDepth: 5000, getInhibited: true)
        let fullQueue = Queue(name: "Q4", depth: 5000, maxDepth: 5000)
        let inhibitedFullQueue = Queue(name: "Q5", depth: 5000, maxDepth: 5000, getInhibited: true, putInhibited: true)

        // Then - canPut (not put inhibited and not full)
        XCTAssertTrue(normalQueue.canPut)
        XCTAssertFalse(putInhibitedQueue.canPut)
        XCTAssertTrue(getInhibitedQueue.canPut)
        XCTAssertFalse(fullQueue.canPut)
        XCTAssertFalse(inhibitedFullQueue.canPut)

        // Then - canGet (not get inhibited)
        XCTAssertTrue(normalQueue.canGet)
        XCTAssertTrue(putInhibitedQueue.canGet)
        XCTAssertFalse(getInhibitedQueue.canGet)
        XCTAssertTrue(fullQueue.canGet)
        XCTAssertFalse(inhibitedFullQueue.canGet)
    }

    func testQueueIsBrowsable() {
        // Given
        let localQueue = Queue(name: "Q1", queueType: .local)
        let aliasQueue = Queue(name: "Q2", queueType: .alias)
        let remoteQueue = Queue(name: "Q3", queueType: .remote)
        let modelQueue = Queue(name: "Q4", queueType: .model)
        let clusterQueue = Queue(name: "Q5", queueType: .cluster)

        // Then
        XCTAssertTrue(localQueue.isBrowsable)
        XCTAssertTrue(aliasQueue.isBrowsable)
        XCTAssertFalse(remoteQueue.isBrowsable)
        XCTAssertFalse(modelQueue.isBrowsable)
        XCTAssertFalse(clusterQueue.isBrowsable)
    }

    func testQueueOpenCounts() {
        // Given
        let queue = Queue(name: "Q1", openInputCount: 3, openOutputCount: 5)
        let unusedQueue = Queue(name: "Q2", openInputCount: 0, openOutputCount: 0)

        // Then
        XCTAssertEqual(queue.totalOpenCount, 8)
        XCTAssertTrue(queue.isInUse)
        XCTAssertEqual(unusedQueue.totalOpenCount, 0)
        XCTAssertFalse(unusedQueue.isInUse)
    }

    // MARK: - Queue Display Helpers Tests

    func testQueueStateSystemImageName() {
        // Given
        let normalQueue = Queue(name: "Q1", depth: 100, maxDepth: 5000)
        let nearCapacityQueue = Queue(name: "Q2", depth: 4100, maxDepth: 5000)
        let criticalQueue = Queue(name: "Q3", depth: 4800, maxDepth: 5000)
        let fullQueue = Queue(name: "Q4", depth: 5000, maxDepth: 5000)
        let inhibitedQueue = Queue(name: "Q5", depth: 100, maxDepth: 5000, putInhibited: true)

        // Then
        XCTAssertEqual(normalQueue.stateSystemImageName, MQQueueType.local.systemImageName)
        XCTAssertEqual(nearCapacityQueue.stateSystemImageName, "exclamationmark.triangle")
        XCTAssertEqual(criticalQueue.stateSystemImageName, "exclamationmark.triangle.fill")
        XCTAssertEqual(fullQueue.stateSystemImageName, "exclamationmark.circle.fill")
        XCTAssertEqual(inhibitedQueue.stateSystemImageName, "lock.fill")
    }

    func testQueueStateColorName() {
        // Given
        let normalQueue = Queue(name: "Q1", depth: 100, maxDepth: 5000)
        let nearCapacityQueue = Queue(name: "Q2", depth: 4100, maxDepth: 5000)
        let criticalQueue = Queue(name: "Q3", depth: 4800, maxDepth: 5000)
        let fullQueue = Queue(name: "Q4", depth: 5000, maxDepth: 5000)
        let inhibitedQueue = Queue(name: "Q5", depth: 100, maxDepth: 5000, putInhibited: true)

        // Then
        XCTAssertEqual(normalQueue.stateColorName, "primary")
        XCTAssertEqual(nearCapacityQueue.stateColorName, "orange")
        XCTAssertEqual(criticalQueue.stateColorName, "red")
        XCTAssertEqual(fullQueue.stateColorName, "red")
        XCTAssertEqual(inhibitedQueue.stateColorName, "yellow")
    }

    func testQueueDepthDisplayString() {
        // Given
        let queue = Queue(name: "Q1", depth: 42, maxDepth: 5000)
        let noMaxQueue = Queue(name: "Q2", depth: 100, maxDepth: 0)

        // Then
        XCTAssertTrue(queue.depthDisplayString.contains("42"))
        XCTAssertTrue(queue.depthDisplayString.contains("5,000") || queue.depthDisplayString.contains("5000"))
        XCTAssertTrue(noMaxQueue.depthDisplayString.contains("100"))
    }

    func testQueueDepthShortString() {
        // Given
        let queue = Queue(name: "Q1", depth: 1234)

        // Then
        XCTAssertTrue(queue.depthShortString.contains("1,234") || queue.depthShortString.contains("1234"))
    }

    func testQueueStatusSummary() {
        // Given
        let normalQueue = Queue(name: "Q1", depth: 100, maxDepth: 5000)
        let fullQueue = Queue(name: "Q2", depth: 5000, maxDepth: 5000)
        let getInhibitedQueue = Queue(name: "Q3", getInhibited: true)
        let putInhibitedQueue = Queue(name: "Q4", putInhibited: true)
        let bothInhibitedQueue = Queue(name: "Q5", getInhibited: true, putInhibited: true)

        // Then
        XCTAssertEqual(normalQueue.statusSummary, "OK")
        XCTAssertTrue(fullQueue.statusSummary.contains("Full"))
        XCTAssertTrue(getInhibitedQueue.statusSummary.contains("Get Inhibited"))
        XCTAssertTrue(putInhibitedQueue.statusSummary.contains("Put Inhibited"))
        XCTAssertTrue(bothInhibitedQueue.statusSummary.contains("Get Inhibited"))
        XCTAssertTrue(bothInhibitedQueue.statusSummary.contains("Put Inhibited"))
    }

    func testQueueAccessibilityLabel() {
        // Given
        let queue = Queue(name: "DEV.QUEUE.1", queueType: .local, depth: 42, maxDepth: 5000)

        // Then
        let label = queue.accessibilityLabel
        XCTAssertTrue(label.contains("Local"))
        XCTAssertTrue(label.contains("queue"))
        XCTAssertTrue(label.contains("DEV.QUEUE.1"))
        XCTAssertTrue(label.contains("42"))
    }

    // MARK: - Queue Protocol Conformance Tests

    func testQueueEquatable() {
        // Given
        let queue1 = Queue(name: "TEST.QUEUE", depth: 100)
        let queue2 = Queue(name: "TEST.QUEUE", depth: 100)
        let queue3 = Queue(name: "OTHER.QUEUE", depth: 100)

        // Then
        XCTAssertEqual(queue1, queue2)
        XCTAssertNotEqual(queue1, queue3)
    }

    func testQueueHashable() {
        // Given
        let queue1 = Queue(name: "TEST.QUEUE", depth: 100)
        let queue2 = Queue(name: "TEST.QUEUE", depth: 100)

        // When
        var set = Set<Queue>()
        set.insert(queue1)
        set.insert(queue2)

        // Then (both should hash to same value since they're equal)
        XCTAssertEqual(queue1.hashValue, queue2.hashValue)
    }

    func testQueueComparable() {
        // Given
        let queueA = Queue(name: "ALPHA.QUEUE")
        let queueB = Queue(name: "BETA.QUEUE")
        let queueZ = Queue(name: "ZULU.QUEUE")
        let queueLower = Queue(name: "alpha.queue")

        // Then
        XCTAssertTrue(queueA < queueB)
        XCTAssertTrue(queueB < queueZ)
        XCTAssertEqual(queueA.name.localizedCaseInsensitiveCompare(queueLower.name), .orderedSame)
    }

    func testQueueCustomStringConvertible() {
        // Given
        let queue = Queue(name: "TEST.QUEUE", queueType: .local, depth: 42, maxDepth: 5000)

        // Then
        let description = queue.description
        XCTAssertTrue(description.contains("TEST.QUEUE"))
        XCTAssertTrue(description.contains("Local"))
        XCTAssertTrue(description.contains("42"))
    }

    // MARK: - Queue Sample Data Tests

    func testQueueSampleData() {
        // Then
        XCTAssertFalse(Queue.samples.isEmpty, "Samples should not be empty")
        XCTAssertNotNil(Queue.sample)
        XCTAssertNotNil(Queue.sampleEmpty)
        XCTAssertNotNil(Queue.sampleNearCapacity)
        XCTAssertNotNil(Queue.sampleFull)
        XCTAssertNotNil(Queue.sampleAlias)
        XCTAssertNotNil(Queue.sampleRemote)
        XCTAssertNotNil(Queue.sampleInhibited)

        // Verify sample properties
        XCTAssertTrue(Queue.sampleEmpty.isEmpty)
        XCTAssertTrue(Queue.sampleNearCapacity.isNearCapacity)
        XCTAssertTrue(Queue.sampleFull.isFull)
        XCTAssertEqual(Queue.sampleAlias.queueType, .alias)
        XCTAssertEqual(Queue.sampleRemote.queueType, .remote)
        XCTAssertTrue(Queue.sampleInhibited.getInhibited || Queue.sampleInhibited.putInhibited)
    }

    // MARK: - QueueManager Tests

    func testQueueManagerInitializationFromConfig() {
        // Given
        let config = ConnectionConfig.sample

        // When
        let qm = QueueManager(config: config)

        // Then
        XCTAssertEqual(qm.id, config.id)
        XCTAssertEqual(qm.config, config)
        XCTAssertEqual(qm.connectionState, .disconnected)
        XCTAssertTrue(qm.queues.isEmpty)
        XCTAssertNil(qm.lastRefreshedAt)
        XCTAssertNil(qm.lastError)
    }

    func testQueueManagerFullInitialization() {
        // Given
        let config = ConnectionConfig.sample
        let queues = Queue.samples
        let refreshDate = Date()

        // When
        let qm = QueueManager(
            config: config,
            connectionState: .connected,
            queues: queues,
            lastRefreshedAt: refreshDate,
            lastError: nil
        )

        // Then
        XCTAssertEqual(qm.connectionState, .connected)
        XCTAssertEqual(qm.queues, queues)
        XCTAssertEqual(qm.lastRefreshedAt, refreshDate)
    }

    // MARK: - QueueManager Connection State Tests

    func testQueueManagerConnectionStateDisplayNames() {
        // Given/Then
        XCTAssertEqual(QueueManager.ConnectionState.disconnected.displayName, "Disconnected")
        XCTAssertEqual(QueueManager.ConnectionState.connecting.displayName, "Connecting...")
        XCTAssertEqual(QueueManager.ConnectionState.connected.displayName, "Connected")
        XCTAssertEqual(QueueManager.ConnectionState.disconnecting.displayName, "Disconnecting...")
        XCTAssertEqual(QueueManager.ConnectionState.error.displayName, "Error")
    }

    func testQueueManagerConnectionStateSystemImages() {
        // Then
        XCTAssertFalse(QueueManager.ConnectionState.disconnected.systemImageName.isEmpty)
        XCTAssertFalse(QueueManager.ConnectionState.connecting.systemImageName.isEmpty)
        XCTAssertFalse(QueueManager.ConnectionState.connected.systemImageName.isEmpty)
        XCTAssertFalse(QueueManager.ConnectionState.disconnecting.systemImageName.isEmpty)
        XCTAssertFalse(QueueManager.ConnectionState.error.systemImageName.isEmpty)
    }

    func testQueueManagerConnectionStateColors() {
        // Then
        XCTAssertEqual(QueueManager.ConnectionState.disconnected.colorName, "secondary")
        XCTAssertEqual(QueueManager.ConnectionState.connecting.colorName, "orange")
        XCTAssertEqual(QueueManager.ConnectionState.connected.colorName, "green")
        XCTAssertEqual(QueueManager.ConnectionState.disconnecting.colorName, "orange")
        XCTAssertEqual(QueueManager.ConnectionState.error.colorName, "red")
    }

    // MARK: - QueueManager Computed Properties Tests

    func testQueueManagerIsConnected() {
        // Given
        let config = ConnectionConfig.sample

        // Then
        XCTAssertTrue(QueueManager(config: config, connectionState: .connected).isConnected)
        XCTAssertFalse(QueueManager(config: config, connectionState: .disconnected).isConnected)
        XCTAssertFalse(QueueManager(config: config, connectionState: .connecting).isConnected)
        XCTAssertFalse(QueueManager(config: config, connectionState: .error).isConnected)
    }

    func testQueueManagerIsTransitioning() {
        // Given
        let config = ConnectionConfig.sample

        // Then
        XCTAssertTrue(QueueManager(config: config, connectionState: .connecting).isTransitioning)
        XCTAssertTrue(QueueManager(config: config, connectionState: .disconnecting).isTransitioning)
        XCTAssertFalse(QueueManager(config: config, connectionState: .connected).isTransitioning)
        XCTAssertFalse(QueueManager(config: config, connectionState: .disconnected).isTransitioning)
        XCTAssertFalse(QueueManager(config: config, connectionState: .error).isTransitioning)
    }

    func testQueueManagerCanConnect() {
        // Given
        let config = ConnectionConfig.sample

        // Then
        XCTAssertTrue(QueueManager(config: config, connectionState: .disconnected).canConnect)
        XCTAssertTrue(QueueManager(config: config, connectionState: .error).canConnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .connected).canConnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .connecting).canConnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .disconnecting).canConnect)
    }

    func testQueueManagerCanDisconnect() {
        // Given
        let config = ConnectionConfig.sample

        // Then
        XCTAssertTrue(QueueManager(config: config, connectionState: .connected).canDisconnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .disconnected).canDisconnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .connecting).canDisconnect)
        XCTAssertFalse(QueueManager(config: config, connectionState: .error).canDisconnect)
    }

    func testQueueManagerQueueCount() {
        // Given
        let config = ConnectionConfig.sample
        let qm = QueueManager(config: config, connectionState: .connected, queues: Queue.samples)

        // Then
        XCTAssertEqual(qm.queueCount, Queue.samples.count)
    }

    func testQueueManagerTotalMessageCount() {
        // Given
        let config = ConnectionConfig.sample
        let queues = [
            Queue(name: "Q1", depth: 100),
            Queue(name: "Q2", depth: 200),
            Queue(name: "Q3", depth: 300)
        ]
        let qm = QueueManager(config: config, connectionState: .connected, queues: queues)

        // Then
        XCTAssertEqual(qm.totalMessageCount, 600)
    }

    func testQueueManagerDisplayProperties() {
        // Given
        let config = ConnectionConfig.sample
        let qm = QueueManager(config: config)

        // Then
        XCTAssertEqual(qm.displayName, config.name)
        XCTAssertEqual(qm.queueManagerName, config.queueManager)
        XCTAssertEqual(qm.connectionString, config.connectionString)
    }

    // MARK: - QueueManager State Mutation Tests

    func testQueueManagerWithConnectionState() {
        // Given
        let qm = QueueManager(config: ConnectionConfig.sample)

        // When
        let connectedQM = qm.withConnectionState(.connected)

        // Then
        XCTAssertEqual(connectedQM.connectionState, .connected)
        XCTAssertNil(connectedQM.lastError, "Error should be cleared when connected")
    }

    func testQueueManagerWithQueues() {
        // Given
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connected)
        let queues = Queue.samples

        // When
        let updatedQM = qm.withQueues(queues)

        // Then
        XCTAssertEqual(updatedQM.queues, queues)
        XCTAssertNotNil(updatedQM.lastRefreshedAt)
    }

    func testQueueManagerWithError() {
        // Given
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connecting)
        let errorMessage = "Connection failed: Host not available"

        // When
        let errorQM = qm.withError(errorMessage)

        // Then
        XCTAssertEqual(errorQM.connectionState, .error)
        XCTAssertEqual(errorQM.lastError, errorMessage)
    }

    func testQueueManagerConnected() {
        // Given
        let qm = QueueManager(config: ConnectionConfig.sample)

        // When
        let connectedQM = qm.connected()

        // Then
        XCTAssertEqual(connectedQM.connectionState, .connected)
    }

    func testQueueManagerDisconnected() {
        // Given
        let qm = QueueManager(
            config: ConnectionConfig.sample,
            connectionState: .connected,
            queues: Queue.samples,
            lastRefreshedAt: Date()
        )

        // When
        let disconnectedQM = qm.disconnected()

        // Then
        XCTAssertEqual(disconnectedQM.connectionState, .disconnected)
        XCTAssertTrue(disconnectedQM.queues.isEmpty, "Queues should be cleared on disconnect")
        XCTAssertNil(disconnectedQM.lastRefreshedAt, "Refresh date should be cleared on disconnect")
    }

    // MARK: - QueueManager Queue Helper Tests

    func testQueueManagerQueueNamed() {
        // Given
        let queues = [
            Queue(name: "DEV.QUEUE.1"),
            Queue(name: "DEV.QUEUE.2"),
            Queue(name: "DEV.QUEUE.3")
        ]
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connected, queues: queues)

        // Then
        XCTAssertNotNil(qm.queue(named: "DEV.QUEUE.2"))
        XCTAssertEqual(qm.queue(named: "DEV.QUEUE.2")?.name, "DEV.QUEUE.2")
        XCTAssertNil(qm.queue(named: "NONEXISTENT"))
    }

    func testQueueManagerQueuesOfType() {
        // Given
        let queues = [
            Queue(name: "LOCAL.Q1", queueType: .local),
            Queue(name: "LOCAL.Q2", queueType: .local),
            Queue(name: "ALIAS.Q1", queueType: .alias),
            Queue(name: "REMOTE.Q1", queueType: .remote)
        ]
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connected, queues: queues)

        // Then
        XCTAssertEqual(qm.queues(ofType: .local).count, 2)
        XCTAssertEqual(qm.queues(ofType: .alias).count, 1)
        XCTAssertEqual(qm.queues(ofType: .remote).count, 1)
        XCTAssertEqual(qm.queues(ofType: .model).count, 0)
    }

    func testQueueManagerQueuesWithMessages() {
        // Given
        let queues = [
            Queue(name: "Q1", depth: 0),
            Queue(name: "Q2", depth: 10),
            Queue(name: "Q3", depth: 0),
            Queue(name: "Q4", depth: 50)
        ]
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connected, queues: queues)

        // Then
        let queuesWithMessages = qm.queuesWithMessages()
        XCTAssertEqual(queuesWithMessages.count, 2)
        XCTAssertTrue(queuesWithMessages.allSatisfy { $0.depth > 0 })
    }

    func testQueueManagerTypedQueueAccessors() {
        // Given
        let queues = [
            Queue(name: "LOCAL.Q", queueType: .local),
            Queue(name: "ALIAS.Q", queueType: .alias),
            Queue(name: "REMOTE.Q", queueType: .remote)
        ]
        let qm = QueueManager(config: ConnectionConfig.sample, connectionState: .connected, queues: queues)

        // Then
        XCTAssertEqual(qm.localQueues.count, 1)
        XCTAssertEqual(qm.aliasQueues.count, 1)
        XCTAssertEqual(qm.remoteQueues.count, 1)
    }

    // MARK: - QueueManager Protocol Conformance Tests

    func testQueueManagerEquatable() {
        // Given
        let config = ConnectionConfig.sample
        let qm1 = QueueManager(config: config, connectionState: .connected)
        let qm2 = QueueManager(config: config, connectionState: .connected)
        let qm3 = QueueManager(config: config, connectionState: .disconnected)

        // Then
        XCTAssertEqual(qm1, qm2)
        XCTAssertNotEqual(qm1, qm3)
    }

    func testQueueManagerHashable() {
        // Given
        let config = ConnectionConfig.sample
        let qm1 = QueueManager(config: config, connectionState: .connected)
        let qm2 = QueueManager(config: config, connectionState: .connected)

        // Then
        XCTAssertEqual(qm1.hashValue, qm2.hashValue)
    }

    func testQueueManagerCustomStringConvertible() {
        // Given
        let config = ConnectionConfig.sample
        let qm = QueueManager(config: config, connectionState: .connected, queues: Queue.samples)

        // Then
        let description = qm.description
        XCTAssertTrue(description.contains(config.name))
        XCTAssertTrue(description.contains("Connected"))
    }

    // MARK: - QueueManager Sample Data Tests

    func testQueueManagerSampleData() {
        // Then
        XCTAssertFalse(QueueManager.samples.isEmpty)
        XCTAssertNotNil(QueueManager.sampleConnected)
        XCTAssertNotNil(QueueManager.sampleDisconnected)
        XCTAssertNotNil(QueueManager.sampleError)

        // Verify sample properties
        XCTAssertTrue(QueueManager.sampleConnected.isConnected)
        XCTAssertFalse(QueueManager.sampleDisconnected.isConnected)
        XCTAssertEqual(QueueManager.sampleError.connectionState, .error)
        XCTAssertNotNil(QueueManager.sampleError.lastError)
    }

    // MARK: - Message Type Tests

    func testMessageTypeRawValues() {
        // Then
        XCTAssertEqual(MessageType.datagram.rawValue, 8)
        XCTAssertEqual(MessageType.request.rawValue, 1)
        XCTAssertEqual(MessageType.reply.rawValue, 2)
        XCTAssertEqual(MessageType.report.rawValue, 4)
        XCTAssertEqual(MessageType.unknown.rawValue, -1)
    }

    func testMessageTypeInitFromRawValue() {
        // Then
        XCTAssertEqual(MessageType(rawValue: 8), .datagram)
        XCTAssertEqual(MessageType(rawValue: 1), .request)
        XCTAssertEqual(MessageType(rawValue: 2), .reply)
        XCTAssertEqual(MessageType(rawValue: 4), .report)
        XCTAssertEqual(MessageType(rawValue: 999), .unknown)
    }

    func testMessageTypeDisplayNames() {
        // Then
        XCTAssertEqual(MessageType.datagram.displayName, "Datagram")
        XCTAssertEqual(MessageType.request.displayName, "Request")
        XCTAssertEqual(MessageType.reply.displayName, "Reply")
        XCTAssertEqual(MessageType.report.displayName, "Report")
        XCTAssertEqual(MessageType.unknown.displayName, "Unknown")
    }

    func testMessageTypeSystemImages() {
        // Then
        XCTAssertFalse(MessageType.datagram.systemImageName.isEmpty)
        XCTAssertFalse(MessageType.request.systemImageName.isEmpty)
        XCTAssertFalse(MessageType.reply.systemImageName.isEmpty)
        XCTAssertFalse(MessageType.report.systemImageName.isEmpty)
        XCTAssertFalse(MessageType.unknown.systemImageName.isEmpty)
    }

    // MARK: - Message Persistence Tests

    func testMessagePersistenceRawValues() {
        // Then
        XCTAssertEqual(MessagePersistence.notPersistent.rawValue, 0)
        XCTAssertEqual(MessagePersistence.persistent.rawValue, 1)
        XCTAssertEqual(MessagePersistence.asQueueDef.rawValue, 2)
        XCTAssertEqual(MessagePersistence.unknown.rawValue, -1)
    }

    func testMessagePersistenceInitFromRawValue() {
        // Then
        XCTAssertEqual(MessagePersistence(rawValue: 0), .notPersistent)
        XCTAssertEqual(MessagePersistence(rawValue: 1), .persistent)
        XCTAssertEqual(MessagePersistence(rawValue: 2), .asQueueDef)
        XCTAssertEqual(MessagePersistence(rawValue: 999), .unknown)
    }

    func testMessagePersistenceDisplayNames() {
        // Then
        XCTAssertEqual(MessagePersistence.notPersistent.displayName, "Not Persistent")
        XCTAssertEqual(MessagePersistence.persistent.displayName, "Persistent")
        XCTAssertEqual(MessagePersistence.asQueueDef.displayName, "As Queue Definition")
    }

    // MARK: - Message Format Tests

    func testMessageFormatRawValues() {
        // Then
        XCTAssertEqual(MessageFormat.string.rawValue, "MQSTR")
        XCTAssertEqual(MessageFormat.rf2Header.rawValue, "MQHRF2")
        XCTAssertEqual(MessageFormat.pcf.rawValue, "MQPCF")
        XCTAssertEqual(MessageFormat.none.rawValue, "MQNONE")
    }

    func testMessageFormatInitFromFormatString() {
        // Then
        XCTAssertEqual(MessageFormat(formatString: "MQSTR"), .string)
        XCTAssertEqual(MessageFormat(formatString: "  MQSTR  "), .string) // With whitespace
        XCTAssertEqual(MessageFormat(formatString: "MQHRF2"), .rf2Header)
        XCTAssertEqual(MessageFormat(formatString: "INVALID"), .unknown)
    }

    func testMessageFormatIsTextBased() {
        // Then
        XCTAssertTrue(MessageFormat.string.isTextBased)
        XCTAssertTrue(MessageFormat.rf2Header.isTextBased)
        XCTAssertTrue(MessageFormat.rfHeader.isTextBased)
        XCTAssertFalse(MessageFormat.pcf.isTextBased)
        XCTAssertFalse(MessageFormat.deadLetter.isTextBased)
        XCTAssertFalse(MessageFormat.none.isTextBased)
    }

    // MARK: - Message Initialization Tests

    func testMessageInitialization() {
        // Given
        let messageId: [UInt8] = Array(repeating: 0x41, count: 24)
        let correlationId: [UInt8] = Array(repeating: 0x42, count: 24)
        let payload = "Test message".data(using: .utf8)!
        let putDate = Date()

        // When
        let message = Message(
            messageId: messageId,
            correlationId: correlationId,
            format: "MQSTR",
            payload: payload,
            putDateTime: putDate,
            putApplicationName: "TestApp",
            messageType: .request,
            persistence: .persistent,
            priority: 7,
            replyToQueue: "REPLY.QUEUE",
            replyToQueueManager: "QM1",
            messageSequenceNumber: 1,
            position: 0
        )

        // Then
        XCTAssertEqual(message.messageId, messageId)
        XCTAssertEqual(message.correlationId, correlationId)
        XCTAssertEqual(message.format, "MQSTR")
        XCTAssertEqual(message.messageFormat, .string)
        XCTAssertEqual(message.payload, payload)
        XCTAssertEqual(message.putDateTime, putDate)
        XCTAssertEqual(message.putApplicationName, "TestApp")
        XCTAssertEqual(message.messageType, .request)
        XCTAssertEqual(message.persistence, .persistent)
        XCTAssertEqual(message.priority, 7)
        XCTAssertEqual(message.replyToQueue, "REPLY.QUEUE")
        XCTAssertEqual(message.replyToQueueManager, "QM1")
        XCTAssertEqual(message.position, 0)
    }

    func testMessageIdGeneration() {
        // Given
        let messageId: [UInt8] = [0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
                                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        // When
        let message = Message(
            messageId: messageId,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(message.id, "414243444546474800000000000000000000000000000000")
        XCTAssertEqual(message.messageIdHex, "414243444546474800000000000000000000000000000000")
        XCTAssertEqual(message.messageIdShort, "4142434445464748")
    }

    func testCorrelationIdProperties() {
        // Given
        let zeroCorrelationId: [UInt8] = Array(repeating: 0, count: 24)
        let nonZeroCorrelationId: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                                              0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                              0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        let messageWithZeroCorrel = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: zeroCorrelationId,
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        let messageWithCorrel = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: nonZeroCorrelationId,
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertFalse(messageWithZeroCorrel.hasCorrelationId)
        XCTAssertTrue(messageWithCorrel.hasCorrelationId)
        XCTAssertEqual(messageWithCorrel.correlationIdShort, "0102030405060708")
    }

    // MARK: - Message Payload Tests

    func testMessagePayloadString() {
        // Given
        let textPayload = "Hello, World!".data(using: .utf8)!
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: textPayload,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(message.payloadString, "Hello, World!")
        XCTAssertFalse(message.isBinaryPayload)
    }

    func testMessagePayloadSize() {
        // Given
        let payload = Data(repeating: 0x00, count: 1024)
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQNONE",
            payload: payload,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(message.payloadSize, 1024)
        XCTAssertFalse(message.payloadSizeFormatted.isEmpty)
    }

    func testMessageBinaryPayloadDetection() {
        // Given
        let binaryPayload = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQNONE",
            payload: binaryPayload,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertTrue(message.isBinaryPayload)
    }

    func testMessagePayloadHexDump() {
        // Given
        let payload = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: payload,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        let hexDump = message.payloadHexDump
        XCTAssertTrue(hexDump.contains("48 65 6C 6C 6F"))
        XCTAssertTrue(hexDump.contains("Hello"))
    }

    func testMessagePayloadPreview() {
        // Given - Text payload
        let shortText = "Short message".data(using: .utf8)!
        let longText = String(repeating: "A", count: 150).data(using: .utf8)!

        let shortMessage = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: shortText,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        let longMessage = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: longText,
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(shortMessage.payloadPreview, "Short message")
        XCTAssertTrue(longMessage.payloadPreview.contains("..."))
        XCTAssertTrue(longMessage.payloadPreview.count <= 103) // 100 + "..."
    }

    // MARK: - Message Reply-To Tests

    func testMessageHasReplyTo() {
        // Given
        let messageWithReplyTo = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            replyToQueue: "REPLY.QUEUE"
        )

        let messageWithoutReplyTo = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            replyToQueue: ""
        )

        // Then
        XCTAssertTrue(messageWithReplyTo.hasReplyTo)
        XCTAssertFalse(messageWithoutReplyTo.hasReplyTo)
    }

    func testMessageReplyToDestination() {
        // Given
        let messageWithBoth = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            replyToQueue: "REPLY.QUEUE",
            replyToQueueManager: "QM1"
        )

        let messageWithQueueOnly = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            replyToQueue: "REPLY.QUEUE",
            replyToQueueManager: ""
        )

        // Then
        XCTAssertEqual(messageWithBoth.replyToDestination, "REPLY.QUEUE@QM1")
        XCTAssertEqual(messageWithQueueOnly.replyToDestination, "REPLY.QUEUE")
    }

    // MARK: - Message Date/Time Tests

    func testMessagePutDateTimeFormatted() {
        // Given
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: Date(),
            putApplicationName: "Test"
        )

        let messageWithoutDate = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertFalse(message.putDateTimeFormatted.isEmpty)
        XCTAssertNotEqual(message.putDateTimeFormatted, "Unknown")
        XCTAssertEqual(messageWithoutDate.putDateTimeFormatted, "Unknown")
    }

    func testMessagePutDateTimeRelative() {
        // Given
        let recentDate = Date().addingTimeInterval(-60) // 1 minute ago
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: recentDate,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertFalse(message.putDateTimeRelative.isEmpty)
        XCTAssertNotEqual(message.putDateTimeRelative, "Unknown")
    }

    // MARK: - Message Priority Tests

    func testMessagePriorityDisplayString() {
        // Given/Then
        let testCases: [(Int32, String)] = [
            (0, "Lowest"),
            (1, "Low"),
            (3, "Low"),
            (4, "Normal"),
            (6, "Normal"),
            (7, "High"),
            (8, "High"),
            (9, "Highest")
        ]

        for (priority, expectedSubstring) in testCases {
            let message = Message(
                messageId: Array(repeating: 0x41, count: 24),
                correlationId: Array(repeating: 0, count: 24),
                format: "MQSTR",
                payload: Data(),
                putDateTime: nil,
                putApplicationName: "Test",
                priority: priority
            )
            XCTAssertTrue(
                message.priorityDisplayString.contains(expectedSubstring),
                "Priority \(priority) should contain '\(expectedSubstring)', got: \(message.priorityDisplayString)"
            )
        }
    }

    // MARK: - Message Display Helpers Tests

    func testMessageSummary() {
        // Given
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: "Test".data(using: .utf8)!,
            putDateTime: nil,
            putApplicationName: "Test",
            messageType: .request,
            persistence: .persistent
        )

        // Then
        let summary = message.summary
        XCTAssertTrue(summary.contains("Request"))
        XCTAssertTrue(summary.contains("String"))
        XCTAssertTrue(summary.contains("Persistent"))
    }

    func testMessageAccessibilityLabel() {
        // Given
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(repeating: 0x00, count: 100),
            putDateTime: Date(),
            putApplicationName: "Test",
            messageType: .datagram,
            persistence: .persistent
        )

        // Then
        let label = message.accessibilityLabel
        XCTAssertTrue(label.contains("Datagram"))
        XCTAssertTrue(label.contains("message"))
        XCTAssertTrue(label.contains("persistent"))
    }

    // MARK: - Message Protocol Conformance Tests

    func testMessageEquatable() {
        // Given
        let messageId1: [UInt8] = Array(repeating: 0x41, count: 24)
        let messageId2: [UInt8] = Array(repeating: 0x42, count: 24)

        let message1 = Message(
            messageId: messageId1,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        let message2 = Message(
            messageId: messageId1,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        let message3 = Message(
            messageId: messageId2,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(message1, message2)
        XCTAssertNotEqual(message1, message3)
    }

    func testMessageHashable() {
        // Given
        let messageId: [UInt8] = Array(repeating: 0x41, count: 24)
        let message1 = Message(
            messageId: messageId,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )
        let message2 = Message(
            messageId: messageId,
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test"
        )

        // Then
        XCTAssertEqual(message1.hashValue, message2.hashValue)
    }

    func testMessageComparable() {
        // Given
        let message1 = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            position: 0
        )

        let message2 = Message(
            messageId: Array(repeating: 0x42, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: Data(),
            putDateTime: nil,
            putApplicationName: "Test",
            position: 1
        )

        // Then
        XCTAssertTrue(message1 < message2)
        XCTAssertFalse(message2 < message1)
    }

    func testMessageCustomStringConvertible() {
        // Given
        let message = Message(
            messageId: Array(repeating: 0x41, count: 24),
            correlationId: Array(repeating: 0, count: 24),
            format: "MQSTR",
            payload: "Test".data(using: .utf8)!,
            putDateTime: nil,
            putApplicationName: "Test",
            messageType: .datagram
        )

        // Then
        let description = message.description
        XCTAssertTrue(description.contains("Message"))
        XCTAssertTrue(description.contains("Datagram"))
        XCTAssertTrue(description.contains("MQSTR"))
    }

    // MARK: - Message Sample Data Tests

    func testMessageSampleData() {
        // Then
        XCTAssertFalse(Message.samples.isEmpty)
        XCTAssertNotNil(Message.sample)
        XCTAssertNotNil(Message.sampleText)
        XCTAssertNotNil(Message.sampleRFH2)
        XCTAssertNotNil(Message.sampleBinary)
        XCTAssertNotNil(Message.sampleJSON)

        // Verify sample properties
        XCTAssertEqual(Message.sampleText.messageFormat, .string)
        XCTAssertEqual(Message.sampleRFH2.messageFormat, .rf2Header)
        XCTAssertTrue(Message.sampleBinary.isBinaryPayload)
    }

    // MARK: - MQQueueType Tests

    func testMQQueueTypeRawValues() {
        // Then
        XCTAssertEqual(MQQueueType.local.rawValue, 1)
        XCTAssertEqual(MQQueueType.alias.rawValue, 3)
        XCTAssertEqual(MQQueueType.remote.rawValue, 6)
        XCTAssertEqual(MQQueueType.model.rawValue, 7)
        XCTAssertEqual(MQQueueType.cluster.rawValue, 8)
    }

    func testMQQueueTypeInitFromRawValue() {
        // Then
        XCTAssertEqual(MQQueueType(rawValue: 1), .local)
        XCTAssertEqual(MQQueueType(rawValue: 3), .alias)
        XCTAssertEqual(MQQueueType(rawValue: 6), .remote)
        XCTAssertEqual(MQQueueType(rawValue: 7), .model)
        XCTAssertEqual(MQQueueType(rawValue: 8), .cluster)
        XCTAssertEqual(MQQueueType(rawValue: 999), .unknown)
    }

    func testMQQueueTypeDisplayNames() {
        // Then
        XCTAssertEqual(MQQueueType.local.displayName, "Local")
        XCTAssertEqual(MQQueueType.alias.displayName, "Alias")
        XCTAssertEqual(MQQueueType.remote.displayName, "Remote")
        XCTAssertEqual(MQQueueType.model.displayName, "Model")
        XCTAssertEqual(MQQueueType.cluster.displayName, "Cluster")
        XCTAssertEqual(MQQueueType.unknown.displayName, "Unknown")
    }

    func testMQQueueTypeSystemImages() {
        // Then
        XCTAssertFalse(MQQueueType.local.systemImageName.isEmpty)
        XCTAssertFalse(MQQueueType.alias.systemImageName.isEmpty)
        XCTAssertFalse(MQQueueType.remote.systemImageName.isEmpty)
        XCTAssertFalse(MQQueueType.model.systemImageName.isEmpty)
        XCTAssertFalse(MQQueueType.cluster.systemImageName.isEmpty)
        XCTAssertFalse(MQQueueType.unknown.systemImageName.isEmpty)
    }
}
