import SwiftUI

// MARK: - EmptyStateView

/// Reusable empty state view for displaying placeholder content when no data is available
/// Provides consistent styling for empty states across the application with support for
/// custom icons, titles, descriptions, and optional action buttons
struct EmptyStateView: View {

    // MARK: - Properties

    /// SF Symbol name for the icon
    let systemImage: String

    /// Main title text
    let title: String

    /// Optional description text providing more context
    let description: String?

    /// Optional action button label
    let actionLabel: String?

    /// Optional action to perform when button is tapped
    let action: (() -> Void)?

    // MARK: - Initialization

    /// Creates an empty state view with optional description and action
    /// - Parameters:
    ///   - systemImage: SF Symbol name for the icon
    ///   - title: Main title text
    ///   - description: Optional description providing more context
    ///   - actionLabel: Optional label for the action button
    ///   - action: Optional action to perform when button is tapped
    init(
        systemImage: String,
        title: String,
        description: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.actionLabel = actionLabel
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        } actions: {
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {

    /// Creates an empty state view for when no queues are available
    /// - Parameter refreshAction: Action to refresh the queue list
    /// - Returns: Configured EmptyStateView for no queues state
    static func noQueues(refreshAction: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            systemImage: "tray",
            title: "No Queues",
            description: "This queue manager has no queues, or you don't have permission to view them.",
            actionLabel: "Refresh",
            action: refreshAction
        )
    }

    /// Creates an empty state view for when no messages are in a queue
    /// - Parameter refreshAction: Optional action to refresh messages
    /// - Returns: Configured EmptyStateView for empty queue state
    static func noMessages(refreshAction: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            systemImage: "tray.2",
            title: "No Messages",
            description: "This queue is empty.",
            actionLabel: refreshAction != nil ? "Refresh" : nil,
            action: refreshAction
        )
    }

    /// Creates an empty state view for when no connections are configured
    /// - Parameter addAction: Action to add a new connection
    /// - Returns: Configured EmptyStateView for no connections state
    static func noConnections(addAction: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            systemImage: "server.rack",
            title: "No Connections",
            description: "Add a queue manager connection to get started.",
            actionLabel: "Add Connection",
            action: addAction
        )
    }

    /// Creates an empty state view for when a connection is required
    /// - Returns: Configured EmptyStateView for select connection state
    static func selectConnection() -> EmptyStateView {
        EmptyStateView(
            systemImage: "sidebar.left",
            title: "Select a Connection",
            description: "Choose a queue manager from the sidebar to view its queues."
        )
    }

    /// Creates an empty state view for when a queue must be selected
    /// - Returns: Configured EmptyStateView for select queue state
    static func selectQueue() -> EmptyStateView {
        EmptyStateView(
            systemImage: "tray.full",
            title: "Select a Queue",
            description: "Choose a queue from the list to browse its messages."
        )
    }

    /// Creates an empty state view for error states
    /// - Parameters:
    ///   - message: Error message to display
    ///   - retryAction: Optional action to retry the failed operation
    /// - Returns: Configured EmptyStateView for error state
    static func error(message: String, retryAction: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "Error",
            description: message,
            actionLabel: retryAction != nil ? "Retry" : nil,
            action: retryAction
        )
    }

    /// Creates an empty state view for loading states
    /// - Parameter message: Loading message to display
    /// - Returns: Configured EmptyStateView for loading state
    static func loading(message: String = "Loading...") -> EmptyStateView {
        EmptyStateView(
            systemImage: "hourglass",
            title: message,
            description: nil
        )
    }
}

// MARK: - LoadingView

/// Loading indicator view with customizable message
/// Displays a spinner with optional loading text
struct LoadingView: View {

    // MARK: - Properties

    /// Loading message to display
    let message: String

    // MARK: - Initialization

    /// Creates a loading view with custom message
    /// - Parameter message: Message to display below the spinner
    init(_ message: String = "Loading...") {
        self.message = message
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Previews

#Preview("Empty State - No Queues") {
    EmptyStateView.noQueues {
        // Refresh action
    }
    .frame(width: 400, height: 300)
}

#Preview("Empty State - No Messages") {
    EmptyStateView.noMessages {
        // Refresh action
    }
    .frame(width: 400, height: 300)
}

#Preview("Empty State - No Connections") {
    EmptyStateView.noConnections {
        // Add action
    }
    .frame(width: 400, height: 300)
}

#Preview("Empty State - Select Connection") {
    EmptyStateView.selectConnection()
        .frame(width: 400, height: 300)
}

#Preview("Empty State - Select Queue") {
    EmptyStateView.selectQueue()
        .frame(width: 400, height: 300)
}

#Preview("Empty State - Error") {
    EmptyStateView.error(message: "Failed to connect to queue manager.") {
        // Retry action
    }
    .frame(width: 400, height: 300)
}

#Preview("Empty State - Custom") {
    EmptyStateView(
        systemImage: "star",
        title: "Custom Title",
        description: "This is a custom description for the empty state.",
        actionLabel: "Custom Action"
    ) {
        // Custom action
    }
    .frame(width: 400, height: 300)
}

#Preview("Loading View") {
    LoadingView("Loading queues...")
        .frame(width: 400, height: 300)
}

#Preview("Loading View - Default") {
    LoadingView()
        .frame(width: 400, height: 300)
}
