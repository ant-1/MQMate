import SwiftUI

// MARK: - QueueRowView

/// Row view for displaying a single queue in the list
/// Shows queue name, type icon, description, and depth indicator with capacity bar
struct QueueRowView: View {

    // MARK: - Properties

    /// Queue to display
    let queue: Queue

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Queue type icon
            queueTypeIcon

            // Queue details
            VStack(alignment: .leading, spacing: 2) {
                Text(queue.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(queue.queueType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let description = queue.queueDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Depth indicator
            depthIndicator
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(queue.accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Subviews

    /// Queue type icon with state coloring
    private var queueTypeIcon: some View {
        Image(systemName: queue.stateSystemImageName)
            .foregroundStyle(iconColor)
            .imageScale(.medium)
            .frame(width: 20, height: 20)
    }

    /// Color for the queue icon based on state
    private var iconColor: Color {
        switch queue.stateColorName {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        default:
            return .secondary
        }
    }

    /// Depth indicator badge
    @ViewBuilder
    private var depthIndicator: some View {
        if queue.hasMessages || queue.maxDepth > 0 {
            VStack(alignment: .trailing, spacing: 2) {
                // Message count
                Text(queue.depthShortString)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(depthColor)

                // Capacity bar (if local queue)
                if queue.queueType == .local && queue.maxDepth > 0 {
                    CapacityBar(percentage: queue.depthPercentage)
                        .frame(width: 50, height: 4)
                }
            }
        }
    }

    /// Color for the depth text based on capacity
    private var depthColor: Color {
        if queue.isFull || queue.isCriticalCapacity {
            return .red
        } else if queue.isNearCapacity {
            return .orange
        } else if queue.hasMessages {
            return .primary
        } else {
            return .secondary
        }
    }

    /// Accessibility hint for the row
    private var accessibilityHint: String {
        if queue.isBrowsable {
            return "Double-click to browse messages. Right-click for options."
        } else {
            return "Right-click for queue information."
        }
    }
}

// MARK: - CapacityBar

/// Small capacity indicator bar showing queue fill percentage
/// Uses color coding to indicate capacity status:
/// - Green: < 50%
/// - Yellow: 50-79%
/// - Orange: 80-94%
/// - Red: >= 95%
struct CapacityBar: View {

    // MARK: - Properties

    /// Fill percentage (0.0 to 1.0)
    let percentage: Double

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * min(percentage, 1.0))
            }
        }
        .accessibilityLabel("Capacity \(Int(percentage * 100)) percent")
        .accessibilityValue(capacityDescription)
    }

    // MARK: - Computed Properties

    /// Color for the fill based on percentage
    private var fillColor: Color {
        if percentage >= 0.95 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else if percentage >= 0.5 {
            return .yellow
        } else {
            return .green
        }
    }

    /// Accessibility description of capacity status
    private var capacityDescription: String {
        if percentage >= 0.95 {
            return "Critical capacity"
        } else if percentage >= 0.8 {
            return "Near capacity"
        } else if percentage >= 0.5 {
            return "Moderate capacity"
        } else {
            return "Low capacity"
        }
    }
}

// MARK: - Previews

#Preview("Queue Row - Normal") {
    List {
        QueueRowView(queue: Queue.sample)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Near Capacity") {
    List {
        QueueRowView(queue: Queue.sampleNearCapacity)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Full") {
    List {
        QueueRowView(queue: Queue.sampleFull)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Empty") {
    List {
        QueueRowView(queue: Queue.sampleEmpty)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Inhibited") {
    List {
        QueueRowView(queue: Queue.sampleInhibited)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Alias") {
    List {
        QueueRowView(queue: Queue.sampleAlias)
    }
    .frame(width: 300, height: 80)
}

#Preview("Queue Row - Remote") {
    List {
        QueueRowView(queue: Queue.sampleRemote)
    }
    .frame(width: 300, height: 80)
}

#Preview("Capacity Bar - All Levels") {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("25%")
                .frame(width: 40, alignment: .trailing)
            CapacityBar(percentage: 0.25)
                .frame(width: 100, height: 6)
            Text("Low")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("50%")
                .frame(width: 40, alignment: .trailing)
            CapacityBar(percentage: 0.5)
                .frame(width: 100, height: 6)
            Text("Moderate")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("80%")
                .frame(width: 40, alignment: .trailing)
            CapacityBar(percentage: 0.8)
                .frame(width: 100, height: 6)
            Text("Near")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("95%")
                .frame(width: 40, alignment: .trailing)
            CapacityBar(percentage: 0.95)
                .frame(width: 100, height: 6)
            Text("Critical")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("100%")
                .frame(width: 40, alignment: .trailing)
            CapacityBar(percentage: 1.0)
                .frame(width: 100, height: 6)
            Text("Full")
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("Queue Types") {
    List {
        QueueRowView(queue: Queue(
            name: "DEV.QUEUE.LOCAL",
            queueType: .local,
            depth: 42,
            maxDepth: 5000
        ))
        QueueRowView(queue: Queue(
            name: "DEV.ALIAS.1",
            queueType: .alias,
            depth: 0,
            maxDepth: 0
        ))
        QueueRowView(queue: Queue(
            name: "DEV.REMOTE.1",
            queueType: .remote,
            depth: 0,
            maxDepth: 0
        ))
        QueueRowView(queue: Queue(
            name: "DEV.MODEL.1",
            queueType: .model,
            depth: 0,
            maxDepth: 5000
        ))
    }
    .frame(width: 350, height: 300)
}
