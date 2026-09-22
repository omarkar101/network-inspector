import SwiftUI
import NetworkInspectorKit

/// Lists the apps with internet access turned off, lets the user add one by
/// bundle identifier, and shows whether the system content filter is running.
struct InternetAccessView: View {
    let controller: InternetAccessController
    /// Known apps, used to show names and icons for blocked bundle identifiers.
    let knownApps: [SourceApp]

    @Environment(\.dismiss) private var dismiss
    @State private var newBundleIdentifier = ""

    private var canAdd: Bool {
        AppBlocklist.isValidBundleIdentifier(newBundleIdentifier)
            && !controller.blocklist.contains(newBundleIdentifier)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FilterStatusRow(
                        state: controller.filterState,
                        hasBlockedApps: !controller.blocklist.isEmpty,
                        retry: controller.retry
                    )
                } footer: {
                    Text("Blocked apps can't reach the network over Wi‑Fi or cellular. "
                        + "iOS only runs this filter in development builds signed with a paid "
                        + "developer account, or on supervised devices.")
                }

                Section("Blocked Apps") {
                    if controller.blocklist.isEmpty {
                        Text("No apps are blocked.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(controller.blocklist.sortedBundleIdentifiers, id: \.self) { bundleIdentifier in
                        BlockedAppRow(
                            bundleIdentifier: bundleIdentifier,
                            app: knownApp(for: bundleIdentifier),
                            isEnforced: controller.isFilterActive
                        )
                            .swipeActions {
                                Button("Allow", systemImage: "wifi") {
                                    controller.setInternetBlocked(false, bundleIdentifier: bundleIdentifier)
                                }
                                .tint(.green)
                            }
                    }
                }

                Section {
                    HStack {
                        TextField("com.example.app", text: $newBundleIdentifier)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Block", action: add)
                            .disabled(!canAdd)
                    }
                } header: {
                    Text("Block by Bundle ID")
                } footer: {
                    Text("Enter the bundle identifier of any installed app.")
                }
            }
            .navigationTitle("Internet Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await controller.refresh() }
        }
    }

    private func knownApp(for bundleIdentifier: String) -> SourceApp? {
        knownApps.first { $0.bundleIdentifier.lowercased() == bundleIdentifier }
    }

    private func add() {
        guard canAdd else { return }
        controller.setInternetBlocked(true, bundleIdentifier: newBundleIdentifier)
        newBundleIdentifier = ""
    }
}

private struct FilterStatusRow: View {
    let state: InternetAccessController.FilterState
    let hasBlockedApps: Bool
    let retry: () -> Void

    var body: some View {
        switch state {
        case .unknown:
            Label("Checking filter…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .off:
            VStack(alignment: .leading, spacing: 8) {
                Label("Filter off", systemImage: "shield.slash")
                    .foregroundStyle(.secondary)
                if hasBlockedApps {
                    Button("Turn On Filter", action: retry)
                        .font(.footnote.weight(.semibold))
                }
            }
        case .on:
            Label("Filter active", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Filter unavailable", systemImage: "exclamationmark.shield.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try Again", action: retry)
                    .font(.footnote.weight(.semibold))
            }
        }
    }
}

private struct BlockedAppRow: View {
    let bundleIdentifier: String
    let app: SourceApp?
    let isEnforced: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let app {
                AppIcon(app: app, size: 32)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app?.displayName ?? bundleIdentifier)
                if app != nil {
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            BlockedIndicator(isEnforced: isEnforced)
        }
    }
}

/// Marks a blocked app: red when the filter is cutting it off, orange when
/// it's on the list but the filter isn't running, so its traffic still flows.
struct BlockedIndicator: View {
    let isEnforced: Bool

    var body: some View {
        Image(systemName: isEnforced ? "wifi.slash" : "wifi.exclamationmark")
            .foregroundStyle(isEnforced ? Color.red : Color.orange)
            .accessibilityLabel(isEnforced ? "Internet off" : "Blocked, but the filter is off")
    }
}

/// Toolbar toggle for one app's internet access.
struct InternetAccessToggle: View {
    let controller: InternetAccessController
    let app: SourceApp

    var body: some View {
        let blocked = controller.isBlocked(app)
        Button {
            controller.setInternetBlocked(!blocked, bundleIdentifier: app.bundleIdentifier)
        } label: {
            Label(
                blocked ? "Turn Internet On" : "Turn Internet Off",
                systemImage: blocked ? "wifi.slash" : "wifi"
            )
        }
        .tint(blocked ? (controller.isFilterActive ? Color.red : Color.orange) : nil)
        .disabled(!controller.canBlock(app))
        .sensoryFeedback(.impact, trigger: blocked)
        .contentTransition(.symbolEffect(.replace))
    }
}

#Preview {
    InternetAccessView(controller: InternetAccessController(), knownApps: SampleData.Apps.all)
}
