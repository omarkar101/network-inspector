import Foundation
import Observation
import NetworkInspectorKit

/// Drives the dashboard: follows the connections the content filter
/// captures on the device (or, in demo mode, a simulated feed of requests)
/// and republishes per-app stats on every tick.
@MainActor
@Observable
final class LiveTrafficModel {
    enum Source {
        /// Real connections captured on this device by the content filter.
        case device
        /// Simulated HTTP requests from made-up apps.
        case demo
    }

    var isLive = true
    var sortOrder: AppStatsSortOrder = .activity
    /// Apps with internet access turned off; the simulated feed drops their
    /// requests the way the content filter drops their real traffic.
    var blocklist = AppBlocklist()

    private(set) var source: Source
    private(set) var requests: [CapturedRequest] = []
    private(set) var connections: [NetworkConnection] = []
    private(set) var stats: [AppTrafficStats] = []
    private(set) var summary = TrafficSummary(stats: [])

    @ObservationIgnored private var log = TrafficLog(capacity: 3_000)
    @ObservationIgnored private var connectionLog = ConnectionLog(capacity: 3_000)
    /// Nil when the app group container isn't available (e.g. unsigned builds).
    @ObservationIgnored private var journal: FlowJournalReader?
    @ObservationIgnored private var generator: LiveTrafficGenerator
    @ObservationIgnored private var now: Date
    private let appNames: AppNameResolver

    init(now: Date = .now, seed: UInt64 = .random(in: 1...UInt64.max), source: Source = .device) {
        self.now = now
        self.source = source
        generator = LiveTrafficGenerator(seed: seed)
        appNames = AppNameResolver()
        journal = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: FlowJournal.appGroupIdentifier)
            .map { FlowJournalReader(directory: $0) }
        log.append(contentsOf: generator.backfill(count: 240, endingAt: now, spanning: 180))
        appNames.onUpdate = { [weak self] in
            self?.appNamesDidChange()
        }
        readJournal()
        refresh()
    }

    /// What the stats count, which decides how the dashboard words them.
    var kind: TrafficKind {
        switch source {
        case .device: .connections
        case .demo: .requests
        }
    }

    var rankedStats: [AppTrafficStats] {
        stats.ranked(by: sortOrder)
    }

    func requests(for app: SourceApp) -> [CapturedRequest] {
        requests.matching(query: "", app: app)
    }

    func connections(for app: SourceApp) -> [NetworkConnection] {
        connections.matching(query: "", app: app)
    }

    /// The latest version of `app`, whose name or icon may have been filled
    /// in since it was shown.
    func current(_ app: SourceApp) -> SourceApp {
        stats.first { $0.app.bundleIdentifier == app.bundleIdentifier }?.app ?? app
    }

    func setSource(_ newSource: Source) {
        guard newSource != source else { return }
        source = newSource
        refresh()
    }

    /// Advances the clock and, while live, takes in new traffic: the
    /// connections captured since the last tick, plus a small burst of
    /// requests in demo mode.
    func tick(at date: Date = .now) {
        guard isLive else { return }
        now = date
        readJournal()
        if source == .demo {
            let burst = Int.random(in: 0...3)
            for _ in 0..<burst {
                let request = generator.next(at: date)
                if !blocklist.contains(request.app.bundleIdentifier) {
                    log.append(request)
                }
            }
        }
        refresh()
    }

    func clear() {
        log.removeAll()
        connectionLog.removeAll()
        refresh()
    }

    /// Ticks until the surrounding task is cancelled (e.g. the view disappears).
    func run() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(700))
            tick()
        }
    }

    /// Takes in the connections the filter recorded since the last read.
    private func readJournal() {
        guard let events = journal?.readNewEvents(), !events.isEmpty else { return }
        for event in events {
            appNames.lookUpIfNeeded(event.sourceAppIdentifier)
        }
        connectionLog.apply(events, directory: appNames.directory)
    }

    private func appNamesDidChange() {
        connectionLog.updateApps(using: appNames.directory)
        refresh()
    }

    private func refresh() {
        requests = log.entries
        connections = connectionLog.connections
        stats = switch source {
        case .device: TrafficStats.perApp(connections, now: now)
        case .demo: TrafficStats.perApp(requests, now: now)
        }
        summary = TrafficSummary(stats: stats)
    }
}
