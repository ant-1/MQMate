import SwiftUI

// MARK: - MessageRowView

/// Row view for displaying a single message in the list
/// Shows message ID, type icon, timestamp, size, and payload preview
struct MessageRowView: View {

    // MARK: - Properties

    /// The message to display
    let message: Message

    /// Whether to show payload preview
    var showPayloadPreview: Bool = true

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Message type icon
            messageTypeIcon

            // Message info
            VStack(alignment: .leading, spacing: 2) {
                // Message ID (short) and timestamp
                messageIdAndTimestamp

                // Format, size, and persistence indicator
                messageMetadata

                // Payload preview (if text and enabled)
                if showPayloadPreview, let preview = payloadPreviewText {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Subviews

    /// Message type icon with color coding
    private var messageTypeIcon: some View {
        Image(systemName: message.typeSystemImageName)
            .foregroundStyle(iconColor)
            .font(.title3)
            .frame(width: 24)
    }

    /// Message ID and timestamp row
    private var messageIdAndTimestamp: some View {
        HStack {
            Text(message.messageIdShort)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            if message.putDateTime != nil {
                Text(message.putDateTimeRelative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Message metadata row showing format, size, persistence, and priority
    private var messageMetadata: some View {
        HStack(spacing: 8) {
            Text(message.messageFormat.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\u{2022}")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(message.payloadSizeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)

            if message.persistence == .persistent {
                Image(systemName: "externaldrive.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.hasReplyTo {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Priority badge for high priority messages
            priorityBadge
        }
    }

    /// Priority badge for high priority messages
    @ViewBuilder
    private var priorityBadge: some View {
        if message.priority >= 7 {
            Text("P\(message.priority)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(message.priority == 9 ? Color.red : Color.orange)
                .clipShape(Capsule())
        }
    }

    // MARK: - Computed Properties

    /// Icon color based on message type
    private var iconColor: Color {
        switch message.messageType {
        case .request:
            return .blue
        case .reply:
            return .green
        case .report:
            return .orange
        case .datagram:
            return .secondary
        case .unknown:
            return .gray
        }
    }

    /// Payload preview text (first line of text payload)
    private var payloadPreviewText: String? {
        guard !message.isBinaryPayload,
              let text = message.payloadString else {
            return nil
        }

        // Get first meaningful line
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let preview = String(firstLine.prefix(100))

        return preview.isEmpty ? nil : preview
    }

    /// Accessibility hint for the row
    private var accessibilityHint: String {
        "Double-click to view message details"
    }
}

// MARK: - Previews

#Preview("Message Row - Text") {
    List {
        MessageRowView(message: Message.sampleText)
    }
    .frame(width: 400, height: 100)
}

#Preview("Message Row - JSON") {
    List {
        MessageRowView(message: Message.sampleJSON)
    }
    .frame(width: 400, height: 120)
}

#Preview("Message Row - Binary") {
    List {
        MessageRowView(message: Message.sampleBinary, showPayloadPreview: false)
    }
    .frame(width: 400, height: 80)
}

#Preview("Message Row - High Priority") {
    List {
        MessageRowView(message: Message.sampleJSON)
    }
    .frame(width: 400, height: 120)
}

#Preview("Message Row - With Reply To") {
    List {
        MessageRowView(message: Message.sampleRFH2)
    }
    .frame(width: 400, height: 120)
}

#Preview("Message Row Types") {
    List {
        MessageRowView(message: Message.sampleText)
        MessageRowView(message: Message.sampleRFH2)
        MessageRowView(message: Message.sampleBinary)
        MessageRowView(message: Message.sampleJSON)
    }
    .frame(width: 450, height: 400)
}
