import SwiftUI
import NetworkInspectorKit

@Observable
final class RequestListModel {
    var searchText: String = ""
    var selectedStatusClass: HTTPStatusClass?
    private(set) var allEntries: [CapturedRequest]

    init(allEntries: [CapturedRequest] = SampleData.capturedRequests) {
        self.allEntries = allEntries
    }

    var filteredEntries: [CapturedRequest] {
        allEntries
            .matching(query: searchText, statusClass: selectedStatusClass)
            .sortedByRecency()
    }
}

struct ContentView: View {
    @State private var model = RequestListModel()

    var body: some View {
        NavigationStack {
            List(model.filteredEntries) { entry in
                RequestRow(entry: entry)
            }
            .listStyle(.plain)
            .navigationTitle("Network Inspector")
            .searchable(text: $model.searchText, prompt: "Search URL or method")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { model.selectedStatusClass = nil }
                        ForEach(HTTPStatusClass.allCases, id: \.self) { statusClass in
                            Button(statusClass.label) { model.selectedStatusClass = statusClass }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if model.filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: model.searchText)
                }
            }
        }
    }
}

private struct RequestRow: View {
    let entry: CapturedRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.method.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())

                Text(entry.url)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 8) {
                Text("\(entry.statusCode)")
                    .foregroundStyle(entry.isFailure ? .red : .secondary)
                Text(entry.statusClass.label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.formattedDuration)
                    .foregroundStyle(.secondary)
                Text(entry.formattedResponseSize)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
