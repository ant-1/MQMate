import SwiftUI

// MARK: - MessageComposerView

/// View for composing and sending messages to a queue
/// Supports text and JSON formats with optional advanced settings
struct MessageComposerView: View {

    // MARK: - Format Enum

    /// The format of the message payload
    enum PayloadFormat: String, CaseIterable, Identifiable {
        case text = "Text"
        case json = "JSON"

        var id: String { rawValue }

        /// Display name for the format
        var displayName: String { rawValue }

        /// SF Symbol for the format
        var systemImageName: String {
            switch self {
            case .text:
                return "doc.text"
            case .json:
                return "curlybraces"
            }
        }

        /// Placeholder text for the editor
        var placeholder: String {
            switch self {
            case .text:
                return "Enter your message text here..."
            case .json:
                return """
                {
                    "key": "value"
                }
                """
            }
        }

        /// MQ format string
        var mqFormat: String {
            switch self {
            case .text, .json:
                return "MQSTR"
            }
        }
    }

    // MARK: - Validation Error

    /// Validation errors for message composition
    enum ValidationError: LocalizedError {
        case payloadEmpty
        case invalidJSON(String)
        case payloadTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .payloadEmpty:
                return "Message payload is required"
            case .invalidJSON(let detail):
                return "Invalid JSON: \(detail)"
            case .payloadTooLarge(let maxSize):
                return "Message exceeds maximum size (\(ByteCountFormatter.string(fromByteCount: Int64(maxSize), countStyle: .file)))"
            }
        }
    }

    // MARK: - Properties

    /// The name of the queue to send to
    let queueName: String

    /// Callback when the message is sent
    let onSend: (Data, MessageType, MessagePersistence, Int32) -> Void

    /// Callback when the form is cancelled
    let onCancel: () -> Void

    // MARK: - Form State

    /// The message payload text
    @State private var payload: String = ""

    /// The selected payload format
    @State private var payloadFormat: PayloadFormat = .text

    /// Message type
    @State private var messageType: MessageType = .datagram

    /// Message persistence
    @State private var persistence: MessagePersistence = .asQueueDef

    /// Message priority (0-9)
    @State private var priority: Int32 = 5

    /// Whether to show advanced options
    @State private var showAdvancedOptions: Bool = false

    /// Validation errors to display
    @State private var validationErrors: [ValidationError] = []

    /// Whether to show validation error alert
    @State private var showValidationAlert: Bool = false

    /// JSON formatting error (real-time feedback)
    @State private var jsonError: String? = nil

    // MARK: - Constants

    /// Maximum message size (100 MB - practical limit for UI)
    private let maxPayloadSize = 100 * 1024 * 1024

    /// Available message types for sending
    private let availableMessageTypes: [MessageType] = [
        .datagram,
        .request
    ]

    /// Available persistence options
    private let availablePersistenceOptions: [MessagePersistence] = [
        .asQueueDef,
        .persistent,
        .notPersistent
    ]

    // MARK: - Computed Properties

    /// Current payload size in bytes
    private var payloadSizeBytes: Int {
        payload.data(using: .utf8)?.count ?? 0
    }

    /// Formatted payload size
    private var payloadSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(payloadSizeBytes), countStyle: .file)
    }

    /// Whether the form is valid for sending
    private var isFormValid: Bool {
        !payload.isEmpty && jsonError == nil && payloadSizeBytes <= maxPayloadSize
    }

    // MARK: - Initialization

    init(
        queueName: String,
        onSend: @escaping (Data, MessageType, MessagePersistence, Int32) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.queueName = queueName
        self.onSend = onSend
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            formHeader

            Divider()

            // Form content
            VStack(spacing: 0) {
                formatSelector

                Divider()

                payloadEditor

                if showAdvancedOptions {
                    Divider()
                    advancedOptionsSection
                }
            }

            Divider()

            // Footer with buttons
            formFooter
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 800)
        .frame(minHeight: 400, idealHeight: 500, maxHeight: 700)
        .alert("Validation Error", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationErrors.map { $0.localizedDescription }.joined(separator: "\n"))
        }
    }

    // MARK: - Subviews

    /// Form header with title
    private var formHeader: some View {
        HStack {
            Text("Send Message")
                .font(.headline)

            Spacer()

            Text("to \(queueName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.bar)
    }

    /// Format selector
    private var formatSelector: some View {
        HStack(spacing: 16) {
            // Format picker
            Picker("Format", selection: $payloadFormat) {
                ForEach(PayloadFormat.allCases) { format in
                    Label(format.displayName, systemImage: format.systemImageName)
                        .tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .onChange(of: payloadFormat) { _, _ in
                validateJSON()
            }

            Spacer()

            // Payload size indicator
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(payloadSizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Advanced options toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvancedOptions.toggle()
                }
            } label: {
                Label(
                    showAdvancedOptions ? "Hide Options" : "Options",
                    systemImage: showAdvancedOptions ? "chevron.up" : "chevron.down"
                )
                .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Payload editor text area
    private var payloadEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $payload)
                .font(.system(.body, design: payloadFormat == .json ? .monospaced : .default))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    Group {
                        if payload.isEmpty {
                            Text(payloadFormat.placeholder)
                                .foregroundStyle(.tertiary)
                                .font(.system(.body, design: payloadFormat == .json ? .monospaced : .default))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: payload) { _, _ in
                    validateJSON()
                }
                .accessibilityLabel("Message payload")
                .accessibilityHint("Enter the message content to send")

            // JSON error indicator
            if let error = jsonError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Advanced options section
    private var advancedOptionsSection: some View {
        Form {
            Section {
                // Message type
                LabeledContent("Message Type") {
                    Picker("", selection: $messageType) {
                        ForEach(availableMessageTypes, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImageName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 150)
                }
                .accessibilityLabel("Message type")
                .accessibilityHint("The type of message to send")

                // Persistence
                LabeledContent("Persistence") {
                    Picker("", selection: $persistence) {
                        ForEach(availablePersistenceOptions, id: \.self) { option in
                            Label(option.displayName, systemImage: option.systemImageName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180)
                }
                .accessibilityLabel("Message persistence")
                .accessibilityHint("Whether the message survives queue manager restarts")

                // Priority
                LabeledContent("Priority") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(priority) },
                                set: { priority = Int32($0) }
                            ),
                            in: 0...9,
                            step: 1
                        )
                        .frame(width: 150)

                        Text(priorityLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                    }
                }
                .accessibilityLabel("Message priority")
                .accessibilityHint("Priority level from 0 (lowest) to 9 (highest)")
            } header: {
                Text("Message Options")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(height: 180)
    }

    /// Priority label based on current value
    private var priorityLabel: String {
        switch priority {
        case 0: return "0 (Low)"
        case 1...3: return "\(priority)"
        case 4...6: return "\(priority) (Med)"
        case 7...8: return "\(priority)"
        case 9: return "9 (High)"
        default: return "\(priority)"
        }
    }

    /// Form footer with action buttons
    private var formFooter: some View {
        HStack {
            // Format JSON button (only visible in JSON mode)
            if payloadFormat == .json {
                Button {
                    formatJSON()
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                }
                .buttonStyle(.borderless)
                .disabled(payload.isEmpty)
                .help("Format JSON with proper indentation")
            }

            Spacer()

            // Cancel button
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            // Send button
            Button("Send Message") {
                sendMessage()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    /// Validate JSON payload if in JSON mode
    private func validateJSON() {
        guard payloadFormat == .json, !payload.isEmpty else {
            jsonError = nil
            return
        }

        guard let data = payload.data(using: .utf8) else {
            jsonError = "Invalid text encoding"
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            jsonError = nil
        } catch let error as NSError {
            // Extract a user-friendly error message
            let description = error.localizedDescription
            if description.contains("line") {
                jsonError = description
            } else {
                jsonError = "Invalid JSON structure"
            }
        }
    }

    /// Format JSON with proper indentation
    private func formatJSON() {
        guard let data = payload.data(using: .utf8) else { return }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let formattedData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let formattedString = String(data: formattedData, encoding: .utf8) {
                payload = formattedString
                jsonError = nil
            }
        } catch {
            // Already handled by validateJSON
        }
    }

    /// Validate the form and return any errors
    private func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedPayload.isEmpty {
            errors.append(.payloadEmpty)
        }

        if payloadSizeBytes > maxPayloadSize {
            errors.append(.payloadTooLarge(maxPayloadSize))
        }

        if payloadFormat == .json, let jsonErr = jsonError {
            errors.append(.invalidJSON(jsonErr))
        }

        return errors
    }

    /// Validate and send the message
    private func sendMessage() {
        let errors = validate()

        if !errors.isEmpty {
            validationErrors = errors
            showValidationAlert = true
            return
        }

        guard let data = payload.data(using: .utf8) else {
            validationErrors = [.payloadEmpty]
            showValidationAlert = true
            return
        }

        onSend(data, messageType, persistence, priority)
    }
}

// MARK: - Previews

#Preview("Text Mode") {
    MessageComposerView(
        queueName: "DEV.QUEUE.1",
        onSend: { data, type, persistence, priority in
            print("Send message: \(data.count) bytes, type: \(type.displayName)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}

#Preview("JSON Mode") {
    MessageComposerView(
        queueName: "DEV.QUEUE.1",
        onSend: { data, type, persistence, priority in
            print("Send message: \(data.count) bytes, type: \(type.displayName)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
