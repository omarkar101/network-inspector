import SwiftUI
import NetworkInspectorKit

/// Searchable, filterable list of connections captured on the device, newest first.
struct ConnectionListView: View {
    let title: String
    let connections: [NetworkConnection]
    /// Whether rows show which app made the connection (off when the list is
    /// already scoped to one app).
    let showsApp: Bool

    @State private var searchText = ""
    @State private var selectedState: ConnectionState?

    private var filteredConnections: [NetworkConnection] {
        connections
            .matching(query: searchText, state: selectedState)
            .sortedByRecency()
    }

    var body: some View {
        let visible = filteredConnections

        List(visible) { connection in
            ConnectionRow(connection: connection, showsApp: showsApp)
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: showsApp ? "Search host or app" : "Search host")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("State", selection: $selectedState) {
                        Text("All").tag(ConnectionState?.none)
                        ForEach(ConnectionState.allCases, id: \.self) { state in
                            Text(state.label).tag(ConnectionState?.some(state))
                        }
                    }
                } label: {
                    Label(
                        "Filter",
                        systemImage: selectedState == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                }
            }
        }
        .overlay {
            if visible.isEmpty {
                if searchText.isEmpty && selectedState == nil {
                    ContentUnavailableView("No Connections", systemImage: "network.slash")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

private struct ConnectionRow: View {
    let connection: NetworkConnection
    let showsApp: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsApp {
                AppIcon(app: connection.app, size: 32)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(connection.transport.label)
                        .font(.caption2.weight(.bold))
                        .monospaced()
                        .foregroundStyle(connection.transport.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(connection.transport.tint.opacity(0.14), in: .capsule)

                    Text(connection.endpoint)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Text(connection.state.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(connection.state.tint)
                    if showsApp {
                        Text(connection.app.displayName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let duration = connection.durationSeconds {
                        Text(Formatting.duration(seconds: duration))
                    }
                    Text(connection.startedAt, style: .relative)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                // Byte counts are only reported once a connection closes.
                if connection.state == .closed {
                    HStack(spacing: 10) {
                        Label(Formatting.byteSize(connection.bytesReceived), systemImage: "arrow.down")
                            .foregroundStyle(Color.blue)
                        Label(Formatting.byteSize(connection.bytesSent), systemImage: "arrow.up")
                            .foregroundStyle(Color.purple)
                    }
                    .font(.caption2.weight(.medium))
                    .labelStyle(ByteCountLabelStyle())
                    .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ByteCountLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

#Preview {
    let directory = AppDirectory()
    let now = Date.now
    NavigationStack {
        ConnectionListView(
            title: "Connections",
            connections: [
                NetworkConnection(
                    app: directory.app(forSourceAppIdentifier: "57T9237FN3.net.whatsapp.WhatsApp"),
                    remoteHost: "g.whatsapp.net",
                    remotePort: 443,
                    startedAt: now.addingTimeInterval(-4)
                ),
                NetworkConnection(
                    app: directory.app(forSourceAppIdentifier: ".com.apple.mobilesafari"),
                    remoteHost: "www.apple.com",
                    remotePort: 443,
                    transport: .udp,
                    startedAt: now.addingTimeInterval(-40),
                    closedAt: now.addingTimeInterval(-12),
                    bytesSent: 2_400,
                    bytesReceived: 512_000
                )
            ],
            showsApp: true
        )
    }
}
