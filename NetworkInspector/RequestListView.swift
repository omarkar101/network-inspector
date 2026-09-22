import SwiftUI
import NetworkInspectorKit

/// Searchable, filterable list of captured requests, newest first.
struct RequestListView: View {
    let title: String
    let entries: [CapturedRequest]
    /// Whether rows show which app issued the request (off when the list is
    /// already scoped to one app).
    let showsApp: Bool

    @State private var searchText = ""
    @State private var selectedStatusClass: HTTPStatusClass?

    private var filteredEntries: [CapturedRequest] {
        entries
            .matching(query: searchText, statusClass: selectedStatusClass)
            .sortedByRecency()
    }

    var body: some View {
        let visible = filteredEntries

        List(visible) { entry in
            RequestRow(entry: entry, showsApp: showsApp)
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: showsApp ? "Search URL, method or app" : "Search URL or method")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedStatusClass) {
                        Text("All").tag(HTTPStatusClass?.none)
                        ForEach(HTTPStatusClass.allCases, id: \.self) { statusClass in
                            Text(statusClass.label).tag(HTTPStatusClass?.some(statusClass))
                        }
                    }
                } label: {
                    Label(
                        "Filter",
                        systemImage: selectedStatusClass == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                }
            }
        }
        .overlay {
            if visible.isEmpty {
                if searchText.isEmpty && selectedStatusClass == nil {
                    ContentUnavailableView("No Requests", systemImage: "network.slash")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

private struct RequestRow: View {
    let entry: CapturedRequest
    let showsApp: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsApp {
                AppIcon(app: entry.app, size: 32)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.method.rawValue)
                        .font(.caption2.weight(.bold))
                        .monospaced()
                        .foregroundStyle(entry.method.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(entry.method.tint.opacity(0.14), in: .capsule)

                    Text(entry.url)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Text("\(entry.statusCode)")
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.statusClass.tint)
                    if showsApp {
                        Text(entry.app.displayName)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(entry.formattedDuration)
                    Text(entry.formattedResponseSize)
                    Text(entry.timestamp, style: .relative)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RequestListView(title: "Requests", entries: SampleData.capturedRequests, showsApp: true)
    }
}
