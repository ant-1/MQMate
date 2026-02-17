import SwiftUI

// MARK: - QueueFormView

/// Form view for creating and editing queues
/// Supports both add and edit modes with form validation
struct QueueFormView: View {

    // MARK: - Mode Enum

    /// The mode of operation for the form
    enum Mode: Equatable {
        case add
        case edit(Queue)

        var title: String {
            switch self {
            case .add:
                return "New Queue"
            case .edit:
                return "Edit Queue"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .add:
                return "Create Queue"
            case .edit:
                return "Save Changes"
            }
        }
    }

    // MARK: - Validation Error

    /// Validation errors for queue configuration
    enum ValidationError: LocalizedError {
        case nameEmpty
        case nameTooLong
        case nameInvalidCharacters

        var errorDescription: String? {
            switch self {
            case .nameEmpty:
                return "Queue name is required"
            case .nameTooLong:
                return "Queue name must be 48 characters or less"
            case .nameInvalidCharacters:
                return "Queue name contains invalid characters"
            }
        }
    }

    // MARK: - Properties

    /// The mode of operation (add or edit)
    let mode: Mode

    /// Callback when the form is saved
    let onSave: (String, MQQueueType) -> Void

    /// Callback when the form is cancelled
    let onCancel: () -> Void

    // MARK: - Form State

    /// Queue name
    @State private var queueName: String = ""

    /// Queue type
    @State private var queueType: MQQueueType = .local

    /// Validation errors to display
    @State private var validationErrors: [ValidationError] = []

    /// Whether to show validation error alert
    @State private var showValidationAlert: Bool = false

    // MARK: - Constants

    /// Maximum length for queue names in IBM MQ
    private let maxQueueNameLength = 48

    /// Queue types available for creation
    private let availableQueueTypes: [MQQueueType] = [
        .local,
        .alias,
        .remote,
        .model
    ]

    // MARK: - Computed Properties

    /// Original queue (for edit mode)
    private var originalQueue: Queue? {
        if case .edit(let queue) = mode {
            return queue
        }
        return nil
    }

    /// Whether the form is valid
    private var isFormValid: Bool {
        validate().isEmpty
    }

    /// Whether the queue type can be changed (only in add mode)
    private var canChangeQueueType: Bool {
        if case .add = mode {
            return true
        }
        return false
    }

    // MARK: - Initialization

    init(
        mode: Mode,
        onSave: @escaping (String, MQQueueType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            formHeader

            Divider()

            // Form content
            Form {
                queueDetailsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer with buttons
            formFooter
        }
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
        .frame(minHeight: 250, idealHeight: 280, maxHeight: 350)
        .onAppear {
            loadInitialValues()
        }
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
            Text(mode.title)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(.bar)
    }

    /// Queue details section
    private var queueDetailsSection: some View {
        Section {
            // Queue name
            LabeledContent("Queue Name") {
                TextField("DEV.QUEUE.1", text: $queueName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .onChange(of: queueName) { _, newValue in
                        // Convert to uppercase and filter invalid characters
                        let filtered = filterQueueName(newValue)
                        if filtered != newValue {
                            queueName = filtered
                        }
                    }
            }
            .accessibilityLabel("Queue name")
            .accessibilityHint("The name of the queue to create")

            // Character count indicator
            HStack {
                Spacer()
                Text("\(queueName.count)/\(maxQueueNameLength)")
                    .font(.caption)
                    .foregroundStyle(queueName.count > maxQueueNameLength ? .red : .secondary)
            }

            // Queue type
            LabeledContent("Queue Type") {
                Picker("", selection: $queueType) {
                    ForEach(availableQueueTypes, id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImageName)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!canChangeQueueType)
            }
            .accessibilityLabel("Queue type")
            .accessibilityHint("The type of queue to create")

            // Queue type description
            Text(queueTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

        } header: {
            Text("Queue Details")
        } footer: {
            if case .edit = mode {
                Text("Queue type cannot be changed after creation.")
                    .font(.caption)
            }
        }
    }

    /// Description for the selected queue type
    private var queueTypeDescription: String {
        switch queueType {
        case .local:
            return "A local queue stores messages on this queue manager."
        case .alias:
            return "An alias queue provides an indirect reference to another queue."
        case .remote:
            return "A remote queue definition points to a queue on another queue manager."
        case .model:
            return "A model queue is a template for creating dynamic queues."
        case .cluster:
            return "A cluster queue is shared across a cluster of queue managers."
        case .unknown:
            return "Unknown queue type."
        }
    }

    /// Form footer with action buttons
    private var formFooter: some View {
        HStack {
            Spacer()

            // Cancel button
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            // Save button
            Button(mode.saveButtonTitle) {
                saveQueue()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    /// Load initial values from the queue (for edit mode)
    private func loadInitialValues() {
        if let queue = originalQueue {
            queueName = queue.name
            queueType = queue.queueType
        }
    }

    /// Filter queue name to valid MQ characters
    /// - Parameter name: The input queue name
    /// - Returns: Filtered queue name with only valid characters
    private func filterQueueName(_ name: String) -> String {
        // IBM MQ queue names can contain: A-Z, 0-9, '.', '/', '_', '%'
        // Convert to uppercase and filter
        let uppercased = name.uppercased()
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./_% ")
        return String(uppercased.unicodeScalars.filter { validCharacters.contains($0) })
    }

    /// Validate the current form values
    /// - Returns: Array of validation errors (empty if valid)
    private func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        let trimmedName = queueName.trimmingCharacters(in: .whitespaces)

        if trimmedName.isEmpty {
            errors.append(.nameEmpty)
        }

        if trimmedName.count > maxQueueNameLength {
            errors.append(.nameTooLong)
        }

        // Check for invalid characters (after filtering, should be clean)
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./_% ")
        if trimmedName.uppercased().unicodeScalars.contains(where: { !validCharacters.contains($0) }) {
            errors.append(.nameInvalidCharacters)
        }

        return errors
    }

    /// Validate and save the queue
    private func saveQueue() {
        let errors = validate()

        if !errors.isEmpty {
            validationErrors = errors
            showValidationAlert = true
            return
        }

        let finalName = queueName.trimmingCharacters(in: .whitespaces).uppercased()
        onSave(finalName, queueType)
    }
}

// MARK: - Previews

#Preview("Add Mode") {
    QueueFormView(
        mode: .add,
        onSave: { name, type in
            print("Create queue: \(name), type: \(type.displayName)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}

#Preview("Edit Mode") {
    QueueFormView(
        mode: .edit(Queue.sample),
        onSave: { name, type in
            print("Update queue: \(name), type: \(type.displayName)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
