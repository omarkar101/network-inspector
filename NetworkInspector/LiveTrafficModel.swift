import Foundation
import Observation
import NetworkInspectorKit

/// Drives the dashboard: owns the rolling traffic log, feeds it from the
/// simulated live generator, and republishes per-app stats on every tick.
@MainActor
@Observable
final class LiveTrafficModel {
    var isLive = true
    var sortOrder: AppStatsSortOrder = .activity

    private(set) var entries: [CapturedRequest] = []
    private(set) var stats: [AppTrafficStats] = []
    private(set) var summary = TrafficSummary(stats: [])

    @ObservationIgnored private var log = TrafficLog(capacity: 3_000)
    @ObservationIgnored private var generator: LiveTrafficGenerator
    @ObservationIgnored private var now: Date

    init(now: Date = .now, seed: UInt64 = .random(in: 1...UInt64.max)) {
        self.now = now
        generator = LiveTrafficGenerator(seed: seed)
        log.append(contentsOf: generator.backfill(count: 240, endingAt: now, spanning: 180))
        refresh()
    }

    var rankedStats: [AppTrafficStats] {
        stats.ranked(by: sortOrder)
    }

    func entries(for app: SourceApp) -> [CapturedRequest] {
        entries.matching(query: "", app: app)
    }

    /// Advances the clock and, while live, captures a small burst of requests.
    func tick(at date: Date = .now) {
        guard isLive else { return }
        now = date
        let burst = Int.random(in: 0...3)
        for _ in 0..<burst {
            log.append(generator.next(at: date))
        }
        refresh()
    }

    func clear() {
        log.removeAll()
        refresh()
    }

    /// Ticks until the surrounding task is cancelled (e.g. the view disappears).
    func run() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(700))
            tick()
        }
    }

    private func refresh() {
        entries = log.entries
        stats = TrafficStats.perApp(log.entries, now: now)
        summary = TrafficSummary(stats: stats)
    }
}
