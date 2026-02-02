import SwiftUI

// MARK: - ConnectionFormView

/// Form view for creating and editing queue manager connections
/// Supports both add and edit modes with form validation
struct ConnectionFormView: View {

    // MARK: - Mode Enum

    /// The mode of operation for the form
    enum Mode: Equatable {
        case add
        case edit(ConnectionConfig)

        var title: String {
            switch self {
            case .add:
                return "New Connection"
            case .edit:
                return "Edit Connection"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .add:
                return "Add Connection"
            case .edit:
                return "Save Changes"
            }
        }
    }

    // MARK: - Properties

    /// The mode of operation (add or edit)
    let mode: Mode

    /// Callback when the form is saved
    let onSave: (ConnectionConfig, String?) -> Void

    /// Callback when the form is cancelled
    let onCancel: () -> Void

    /// Optional callback to check if password exists (for edit mode)
    var hasExistingPassword: Bool = false

    // MARK: - Form State

    /// Connection name
    @State private var name: String = ""

    /// Queue manager name
    @State private var queueManager: String = ""

    /// Hostname or IP address
    @State private var hostname: String = ""

    /// Port number
    @State private var port: Int = 1414

    /// Channel name
    @State private var channel: String = ""

    /// Username (optional)
    @State private var username: String = ""

    /// Password (stored in Keychain)
    @State private var password: String = ""

    /// Whether password field has been modified (for edit mode)
    @State private var passwordModified: Bool = false

    /// Whether to show the password in plain text
    @State private var showPassword: Bool = false

    /// Validation errors to display
    @State private var validationErrors: [ConnectionConfig.ValidationError] = []

    /// Whether to show validation error alert
    @State private var showValidationAlert: Bool = false

    /// Port field as string for TextField binding
    @State private var portString: String = "1414"

    // MARK: - Computed Properties

    /// Original config (for edit mode)
    private var originalConfig: ConnectionConfig? {
        if case .edit(let config) = mode {
            return config
        }
        return nil
    }

    /// Whether the form is valid
    private var isFormValid: Bool {
        let config = buildConnectionConfig()
        return config.validate().isValid && !hasPortError
    }

    /// Whether there's a port input error
    private var hasPortError: Bool {
        guard let portValue = Int(portString) else { return true }
        return portValue < 1 || portValue > 65535
    }

    /// Placeholder text for password field in edit mode
    private var passwordPlaceholder: String {
        if case .edit = mode, hasExistingPassword, !passwordModified {
            return "••••••••"
        }
        return "Password (optional)"
    }

    // MARK: - Initialization

    init(
        mode: Mode,
        hasExistingPassword: Bool = false,
        onSave: @escaping (ConnectionConfig, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.hasExistingPassword = hasExistingPassword
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
                connectionDetailsSection
                authenticationSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Footer with buttons
            formFooter
        }
        .frame(minWidth: 450, idealWidth: 500, maxWidth: 600)
        .frame(minHeight: 450, idealHeight: 500, maxHeight: 600)
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

    /// Connection details section
    private var connectionDetailsSection: some View {
        Section {
            // Connection name
            LabeledContent("Name") {
                TextField("My Queue Manager", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Connection name")
            .accessibilityHint("A friendly name for this connection")

            // Queue manager name
            LabeledContent("Queue Manager") {
                TextField("QM1", text: $queueManager)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textCase(.uppercase)
            }
            .accessibilityLabel("Queue manager name")
            .accessibilityHint("The name of the IBM MQ queue manager")

            // Hostname
            LabeledContent("Hostname") {
                TextField("localhost", text: $hostname)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
            }
            .accessibilityLabel("Hostname")
            .accessibilityHint("The hostname or IP address of the queue manager server")

            // Port
            LabeledContent("Port") {
                TextField("1414", text: $portString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: portString) { _, newValue in
                        // Filter to only digits
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            portString = filtered
                        }
                        // Update port value
                        if let portValue = Int(filtered) {
                            port = portValue
                        }
                    }

                if hasPortError && !portString.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .help("Port must be between 1 and 65535")
                }
            }
            .accessibilityLabel("Port number")
            .accessibilityHint("The port number for the MQ listener, typically 1414")

            // Channel
            LabeledContent("Channel") {
                TextField("SYSTEM.DEF.SVRCONN", text: $channel)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
            }
            .accessibilityLabel("Channel name")
            .accessibilityHint("The server connection channel name")
        } header: {
            Text("Connection Details")
        }
    }

    /// Authentication section
    private var authenticationSection: some View {
        Section {
            // Username
            LabeledContent("Username") {
                TextField("Optional", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textContentType(.username)
                    .autocorrectionDisabled()
            }
            .accessibilityLabel("Username")
            .accessibilityHint("Optional username for authentication")

            // Password
            LabeledContent("Password") {
                HStack(spacing: 8) {
                    Group {
                        if showPassword {
                            TextField(passwordPlaceholder, text: $password)
                        } else {
                            SecureField(passwordPlaceholder, text: $password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .textContentType(.password)
                    .onChange(of: password) { _, _ in
                        passwordModified = true
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(showPassword ? "Hide password" : "Show password")
                }
            }
            .accessibilityLabel("Password")
            .accessibilityHint("Optional password for authentication. Stored securely in Keychain.")

            // Password note
            if case .edit = mode, hasExistingPassword, !passwordModified {
                Text("Leave blank to keep the existing password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Password is stored securely in your Keychain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Authentication")
        } footer: {
            Text("Credentials are optional if the queue manager doesn't require authentication.")
                .font(.caption)
        }
    }

    /// Form footer with action buttons
    private var formFooter: some View {
        HStack {
            // Test connection button (future enhancement)
            Button {
                // TODO: Implement test connection
            } label: {
                Label("Test Connection", systemImage: "bolt")
            }
            .disabled(true) // Disabled until implemented
            .help("Test connection is not yet implemented")

            Spacer()

            // Cancel button
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            // Save button
            Button(mode.saveButtonTitle) {
                saveConnection()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    /// Load initial values from the config (for edit mode)
    private func loadInitialValues() {
        if let config = originalConfig {
            name = config.name
            queueManager = config.queueManager
            hostname = config.hostname
            port = config.port
            portString = String(config.port)
            channel = config.channel
            username = config.username ?? ""
            password = ""
            passwordModified = false
        }
    }

    /// Build a ConnectionConfig from the current form values
    private func buildConnectionConfig() -> ConnectionConfig {
        if let original = originalConfig {
            // Edit mode - preserve the original ID and dates
            var config = ConnectionConfig(
                id: original.id,
                name: name.trimmingCharacters(in: .whitespaces),
                queueManager: queueManager.trimmingCharacters(in: .whitespaces).uppercased(),
                hostname: hostname.trimmingCharacters(in: .whitespaces),
                port: port,
                channel: channel.trimmingCharacters(in: .whitespaces).uppercased(),
                username: username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : username.trimmingCharacters(in: .whitespaces)
            )
            // Note: createdAt and other dates are set in the init, but we'll handle this in ConnectionManager
            return config
        } else {
            // Add mode - create new config
            return ConnectionConfig(
                name: name.trimmingCharacters(in: .whitespaces),
                queueManager: queueManager.trimmingCharacters(in: .whitespaces).uppercased(),
                hostname: hostname.trimmingCharacters(in: .whitespaces),
                port: port,
                channel: channel.trimmingCharacters(in: .whitespaces).uppercased(),
                username: username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : username.trimmingCharacters(in: .whitespaces)
            )
        }
    }

    /// Validate and save the connection
    private func saveConnection() {
        let config = buildConnectionConfig()
        let validation = config.validate()

        if !validation.isValid {
            validationErrors = validation.errors
            showValidationAlert = true
            return
        }

        // Determine password to save
        let passwordToSave: String?
        if passwordModified || mode == .add {
            // Only save password if it was modified or this is a new connection
            passwordToSave = password.isEmpty ? nil : password
        } else {
            // Keep existing password (nil means don't update)
            passwordToSave = nil
        }

        onSave(config, passwordToSave)
    }
}

// MARK: - Previews

#Preview("Add Mode") {
    ConnectionFormView(
        mode: .add,
        onSave: { config, password in
            print("Save: \(config.name), password: \(password ?? "none")")
        },
        onCancel: {
            print("Cancel")
        }
    )
}

#Preview("Edit Mode") {
    ConnectionFormView(
        mode: .edit(ConnectionConfig.sample),
        hasExistingPassword: true,
        onSave: { config, password in
            print("Save: \(config.name), password: \(password ?? "keep existing")")
        },
        onCancel: {
            print("Cancel")
        }
    )
}

#Preview("Edit Mode - No Password") {
    ConnectionFormView(
        mode: .edit(ConnectionConfig.sample),
        hasExistingPassword: false,
        onSave: { config, password in
            print("Save: \(config.name), password: \(password ?? "none")")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
