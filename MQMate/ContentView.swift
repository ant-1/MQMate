import SwiftUI

/// Main content view with NavigationSplitView three-column layout
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar: Connection list placeholder
            Text("Connections")
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } content: {
            // Content: Queue list placeholder
            Text("Select a connection")
                .navigationSplitViewColumnWidth(min: 200, ideal: 300)
        } detail: {
            // Detail: Message browser placeholder
            Text("Select a queue")
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
}
