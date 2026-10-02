import Foundation
import NetworkInspectorKit

/// Names the apps seen in captured traffic. Popular apps and iOS services
/// are named from `KnownApps` right away; App Store lookups add icons and
/// name everything else. Lookups run one at a time and are cached across
/// launches.
@MainActor
final class AppNameResolver {
    private(set) var directory: AppDirectory
    /// Called after a lookup adds a name or icon to `directory`.
    var onUpdate: (@MainActor () -> Void)?

    private let defaults: UserDefaults
    /// Lowercased bundle identifiers already looked up (or queued), so each
    /// is only asked about once.
    private var attempted: Set<String>
    /// Apps the App Store didn't have, and when it was last asked.
    private var misses: [String: Date]
    private var queue: [String] = []
    private var worker: Task<Void, Never>?

    private static let listingsKey = "appStoreListings"
    private static let missesKey = "appStoreMisses"
    /// How long to wait before asking the App Store again about an app it didn't have.
    private static let missRetryInterval: TimeInterval = 7 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let listings = defaults.data(forKey: Self.listingsKey)
            .flatMap { try? JSONDecoder().decode([AppStoreListing].self, from: $0) } ?? []
        directory = AppDirectory(listings: listings)
        let storedMisses = defaults.data(forKey: Self.missesKey)
            .flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
        misses = storedMisses.filter { Date.now.timeIntervalSince($0.value) < Self.missRetryInterval }
        attempted = Set(directory.listings.keys).union(misses.keys)
    }

    /// Queues App Store lookups for an app (and for the app containing it, if
    /// it's an extension) unless they were already done.
    func lookUpIfNeeded(_ sourceAppIdentifier: String?) {
        for candidate in AppDirectory.lookupCandidates(forSourceAppIdentifier: sourceAppIdentifier) {
            guard attempted.insert(candidate.lowercased()).inserted else { continue }
            queue.append(candidate)
        }
        startWorkerIfNeeded()
    }

    private func startWorkerIfNeeded() {
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task { [weak self] in
            while let bundleIdentifier = self?.dequeue() {
                let result = await Self.lookUp(bundleIdentifier)
                self?.record(result, for: bundleIdentifier)
                // The lookup API allows about 20 requests a minute.
                try? await Task.sleep(for: .seconds(3))
            }
            self?.worker = nil
        }
    }

    private func dequeue() -> String? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    private func record(_ result: LookupResult, for bundleIdentifier: String) {
        switch result {
        case .found(let listing):
            directory.add(listing)
            save()
            onUpdate?()
        case .notListed:
            misses[bundleIdentifier.lowercased()] = .now
            save()
        case .failed:
            // Offline or rate limited: try again next launch.
            break
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Array(directory.listings.values)) {
            defaults.set(data, forKey: Self.listingsKey)
        }
        if let data = try? JSONEncoder().encode(misses) {
            defaults.set(data, forKey: Self.missesKey)
        }
    }

    private enum LookupResult: Sendable {
        case found(AppStoreListing)
        case notListed
        case failed
    }

    nonisolated private static func lookUp(_ bundleIdentifier: String) async -> LookupResult {
        let country = Locale.current.region?.identifier
        guard let url = AppStoreLookup.url(bundleIdentifier: bundleIdentifier, country: country) else {
            return .failed
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .failed }
            guard let listing = try AppStoreLookup.listing(from: data, bundleIdentifier: bundleIdentifier) else {
                return .notListed
            }
            return .found(listing)
        } catch {
            return .failed
        }
    }
}
