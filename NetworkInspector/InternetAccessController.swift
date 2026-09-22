import Foundation
import Observation
@preconcurrency import NetworkExtension
import NetworkInspectorKit

/// Owns the list of apps with internet access turned off and pushes it to the
/// system content filter (the `NetworkInspectorFilterData` extension).
///
/// iOS only runs third-party content filters on supervised devices, Screen
/// Time child devices, or development-signed builds, and the Network
/// Extension capability needs a paid developer account. When the filter
/// can't be installed, the list is still kept and `filterState` says why.
@MainActor
@Observable
final class InternetAccessController {
    enum FilterState: Equatable {
        case unknown
        case off
        case on
        case failed(String)
    }

    private(set) var blocklist: AppBlocklist
    private(set) var filterState: FilterState = .unknown

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var pendingSync: Task<Void, Never>?

    private static let defaultsKey = "blockedApps"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(AppBlocklist.self, from: data) {
            blocklist = stored
        } else {
            blocklist = AppBlocklist()
        }
    }

    func isBlocked(_ app: SourceApp) -> Bool {
        blocklist.contains(app.bundleIdentifier)
    }

    func canBlock(_ app: SourceApp) -> Bool {
        AppBlocklist.isValidBundleIdentifier(app.bundleIdentifier)
    }

    /// Turns internet access on or off for an app and updates the filter.
    func setInternetBlocked(_ blocked: Bool, bundleIdentifier: String) {
        var updated = blocklist
        updated.setBlocked(blocked, bundleIdentifier: bundleIdentifier)
        guard updated != blocklist else { return }
        blocklist = updated
        if let data = try? JSONEncoder().encode(blocklist) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
        scheduleSync()
    }

    /// Reads the filter's current state without changing it.
    func refresh() async {
        let manager = NEFilterManager.shared()
        do {
            try await load(manager)
            filterState = manager.isEnabled ? .on : .off
        } catch {
            filterState = .failed(Self.describe(error))
        }
    }

    /// Re-applies the current list, e.g. after the user denied the first prompt.
    func retry() {
        scheduleSync()
    }

    /// Queues a sync behind any in-flight one so saves never interleave.
    private func scheduleSync() {
        let previous = pendingSync
        pendingSync = Task {
            await previous?.value
            await sync()
        }
    }

    /// Saves the current list into the filter configuration, enabling the
    /// filter while any app is blocked and disabling it otherwise. The first
    /// save shows the system "Filter Network Content" permission prompt.
    private func sync() async {
        let manager = NEFilterManager.shared()
        do {
            try await load(manager)
            if blocklist.isEmpty && manager.providerConfiguration == nil {
                filterState = .off
                return
            }

            let configuration = manager.providerConfiguration ?? NEFilterProviderConfiguration()
            configuration.filterSockets = true
            configuration.vendorConfiguration = blocklist.vendorConfiguration
            manager.providerConfiguration = configuration
            manager.localizedDescription = "Network Inspector"
            manager.isEnabled = !blocklist.isEmpty

            try await save(manager)
            filterState = manager.isEnabled ? .on : .off
        } catch {
            filterState = .failed(Self.describe(error))
        }
    }

    private func load(_ manager: NEFilterManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func save(_ manager: NEFilterManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func describe(_ error: any Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NEFilterErrorDomain,
              let code = NEFilterManagerError(rawValue: nsError.code)
        else { return error.localizedDescription }

        switch code {
        case .configurationPermissionDenied:
            return "Permission to filter network content was denied."
        case .configurationInvalid, .configurationDisabled, .configurationStale, .configurationCannotBeRemoved:
            return "The filter configuration couldn't be saved (\(error.localizedDescription))."
        default:
            return "This device doesn't allow content filters from this build. "
                + "It needs a development-signed build with the Network Extension capability "
                + "(paid developer account), or a supervised device."
        }
    }
}
