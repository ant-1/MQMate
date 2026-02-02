import Foundation

// MARK: - Queue

/// Represents an IBM MQ queue with its properties and current state
/// Used to display queue information in the queue list view
public struct Queue: Identifiable, Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier (same as queue name since names are unique within a queue manager)
    public let id: String

    /// Queue name as defined in the queue manager
    public let name: String

    /// Type of queue (local, alias, remote, model, cluster)
    public let queueType: MQQueueType

    /// Current number of messages in the queue
    public let depth: Int32

    /// Maximum number of messages the queue can hold
    public let maxDepth: Int32

    /// Description of the queue (if available)
    public let queueDescription: String?

    /// Whether get operations are inhibited on this queue
    public let getInhibited: Bool

    /// Whether put operations are inhibited on this queue
    public let putInhibited: Bool

    /// Number of applications with the queue open for input
    public let openInputCount: Int32

    /// Number of applications with the queue open for output
    public let openOutputCount: Int32

    /// Timestamp when this queue information was last refreshed
    public let lastRefreshedAt: Date

    // MARK: - Initialization

    /// Create a new Queue instance with all properties
    /// - Parameters:
    ///   - name: Queue name
    ///   - queueType: Type of queue
    ///   - depth: Current message depth
    ///   - maxDepth: Maximum queue depth
    ///   - queueDescription: Optional description
    ///   - getInhibited: Whether gets are inhibited
    ///   - putInhibited: Whether puts are inhibited
    ///   - openInputCount: Number of input openers
    ///   - openOutputCount: Number of output openers
    ///   - lastRefreshedAt: When this data was retrieved
    public init(
        name: String,
        queueType: MQQueueType = .local,
        depth: Int32 = 0,
        maxDepth: Int32 = 5000,
        queueDescription: String? = nil,
        getInhibited: Bool = false,
        putInhibited: Bool = false,
        openInputCount: Int32 = 0,
        openOutputCount: Int32 = 0,
        lastRefreshedAt: Date = Date()
    ) {
        self.id = name
        self.name = name
        self.queueType = queueType
        self.depth = depth
        self.maxDepth = maxDepth
        self.queueDescription = queueDescription
        self.getInhibited = getInhibited
        self.putInhibited = putInhibited
        self.openInputCount = openInputCount
        self.openOutputCount = openOutputCount
        self.lastRefreshedAt = lastRefreshedAt
    }

    // MARK: - Computed Properties

    /// Depth as a percentage of max depth (0.0 to 1.0)
    public var depthPercentage: Double {
        guard maxDepth > 0 else { return 0 }
        return Double(depth) / Double(maxDepth)
    }

    /// Depth percentage formatted for display (e.g., "42%")
    public var depthPercentageFormatted: String {
        guard maxDepth > 0 else { return "N/A" }
        let percentage = Int(depthPercentage * 100)
        return "\(percentage)%"
    }

    /// Check if queue is near capacity (> 80%)
    public var isNearCapacity: Bool {
        depthPercentage > 0.8
    }

    /// Check if queue is at critical capacity (> 95%)
    public var isCriticalCapacity: Bool {
        depthPercentage > 0.95
    }

    /// Check if queue is full
    public var isFull: Bool {
        maxDepth > 0 && depth >= maxDepth
    }

    /// Check if queue is empty
    public var isEmpty: Bool {
        depth == 0
    }

    /// Check if queue has messages
    public var hasMessages: Bool {
        depth > 0
    }

    /// Check if queue can receive messages (not put inhibited and not full)
    public var canPut: Bool {
        !putInhibited && !isFull
    }

    /// Check if queue can have messages retrieved (not get inhibited)
    public var canGet: Bool {
        !getInhibited
    }

    /// Check if this is a browsable queue type
    public var isBrowsable: Bool {
        queueType == .local || queueType == .alias
    }

    /// Total number of applications with this queue open
    public var totalOpenCount: Int32 {
        openInputCount + openOutputCount
    }

    /// Check if any applications have this queue open
    public var isInUse: Bool {
        totalOpenCount > 0
    }

    // MARK: - Display Helpers

    /// SF Symbol name for the current queue state
    public var stateSystemImageName: String {
        if isFull {
            return "exclamationmark.circle.fill"
        } else if isCriticalCapacity {
            return "exclamationmark.triangle.fill"
        } else if isNearCapacity {
            return "exclamationmark.triangle"
        } else if putInhibited || getInhibited {
            return "lock.fill"
        } else {
            return queueType.systemImageName
        }
    }

    /// Color name for the current queue state (use with SwiftUI Color)
    public var stateColorName: String {
        if isFull {
            return "red"
        } else if isCriticalCapacity {
            return "red"
        } else if isNearCapacity {
            return "orange"
        } else if putInhibited || getInhibited {
            return "yellow"
        } else {
            return "primary"
        }
    }

    /// Formatted depth display (e.g., "42 / 5,000")
    public var depthDisplayString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let depthStr = formatter.string(from: NSNumber(value: depth)) ?? "\(depth)"

        if maxDepth > 0 {
            let maxStr = formatter.string(from: NSNumber(value: maxDepth)) ?? "\(maxDepth)"
            return "\(depthStr) / \(maxStr)"
        } else {
            return depthStr
        }
    }

    /// Short depth display (just the current depth)
    public var depthShortString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: depth)) ?? "\(depth)"
    }

    /// Status summary for the queue
    public var statusSummary: String {
        var statuses: [String] = []

        if isFull {
            statuses.append("Full")
        } else if isCriticalCapacity {
            statuses.append("Critical")
        } else if isNearCapacity {
            statuses.append("Near Capacity")
        }

        if getInhibited {
            statuses.append("Get Inhibited")
        }

        if putInhibited {
            statuses.append("Put Inhibited")
        }

        if statuses.isEmpty {
            return "OK"
        }

        return statuses.joined(separator: ", ")
    }

    /// Accessibility label for the queue
    public var accessibilityLabel: String {
        var parts: [String] = [
            "\(queueType.displayName) queue",
            name,
            "\(depth) messages"
        ]

        if maxDepth > 0 {
            parts.append("of \(maxDepth) maximum")
        }

        if putInhibited {
            parts.append("put inhibited")
        }

        if getInhibited {
            parts.append("get inhibited")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - CustomStringConvertible

extension Queue: CustomStringConvertible {
    public var description: String {
        "Queue(\(name): \(queueType.displayName), depth=\(depth)/\(maxDepth))"
    }
}

// MARK: - Comparable

extension Queue: Comparable {
    /// Compare queues by name (case-insensitive)
    public static func < (lhs: Queue, rhs: Queue) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Sample Data for Previews

extension Queue {
    /// Sample queues for SwiftUI previews and testing
    public static let samples: [Queue] = [
        Queue(
            name: "DEV.QUEUE.1",
            queueType: .local,
            depth: 42,
            maxDepth: 5000,
            queueDescription: "Development queue for testing",
            getInhibited: false,
            putInhibited: false,
            openInputCount: 1,
            openOutputCount: 2
        ),
        Queue(
            name: "DEV.QUEUE.2",
            queueType: .local,
            depth: 0,
            maxDepth: 5000,
            queueDescription: "Empty development queue"
        ),
        Queue(
            name: "DEV.QUEUE.3",
            queueType: .local,
            depth: 4500,
            maxDepth: 5000,
            queueDescription: "High capacity queue"
        ),
        Queue(
            name: "DEV.QUEUE.FULL",
            queueType: .local,
            depth: 5000,
            maxDepth: 5000,
            queueDescription: "Full queue"
        ),
        Queue(
            name: "DEV.ALIAS.1",
            queueType: .alias,
            depth: 0,
            maxDepth: 0,
            queueDescription: "Alias to DEV.QUEUE.1"
        ),
        Queue(
            name: "DEV.REMOTE.1",
            queueType: .remote,
            depth: 0,
            maxDepth: 0,
            queueDescription: "Remote queue definition"
        ),
        Queue(
            name: "DEV.MODEL.1",
            queueType: .model,
            depth: 0,
            maxDepth: 5000,
            queueDescription: "Model queue for dynamic creation"
        ),
        Queue(
            name: "SYSTEM.DEAD.LETTER.QUEUE",
            queueType: .local,
            depth: 3,
            maxDepth: 10000,
            queueDescription: "Dead letter queue"
        ),
        Queue(
            name: "DEV.INHIBITED.QUEUE",
            queueType: .local,
            depth: 100,
            maxDepth: 5000,
            getInhibited: true,
            putInhibited: true
        )
    ]

    /// Single sample queue for SwiftUI previews
    public static let sample = samples[0]

    /// Empty queue sample
    public static let sampleEmpty = samples[1]

    /// Near capacity queue sample
    public static let sampleNearCapacity = samples[2]

    /// Full queue sample
    public static let sampleFull = samples[3]

    /// Alias queue sample
    public static let sampleAlias = samples[4]

    /// Remote queue sample
    public static let sampleRemote = samples[5]

    /// Inhibited queue sample
    public static let sampleInhibited = samples[8]
}
