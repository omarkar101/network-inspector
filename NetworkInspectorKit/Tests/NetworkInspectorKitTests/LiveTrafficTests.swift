import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("Live traffic")
struct LiveTrafficTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func fingerprint(_ entry: CapturedRequest) -> String {
        "\(entry.app.id) \(entry.method.rawValue) \(entry.url) \(entry.statusCode) "
            + "\(entry.durationSeconds) \(entry.requestBodySize) \(entry.responseBodySize) \(entry.timestamp)"
    }

    // MARK: Generator

    @Test("seeded RNG is deterministic and seed-dependent")
    func seededRandom() {
        var a = SeededRandomNumberGenerator(seed: 42)
        var b = SeededRandomNumberGenerator(seed: 42)
        var c = SeededRandomNumberGenerator(seed: 43)
        let first = (0..<5).map { _ in a.next() }
        #expect(first == (0..<5).map { _ in b.next() })
        #expect(first != (0..<5).map { _ in c.next() })
    }

    @Test("same seed produces the same traffic")
    func deterministicTraffic() {
        var a = LiveTrafficGenerator(seed: 7)
        var b = LiveTrafficGenerator(seed: 7)
        let left = a.backfill(count: 50, endingAt: start, spanning: 60).map(fingerprint)
        let right = b.backfill(count: 50, endingAt: start, spanning: 60).map(fingerprint)
        #expect(left == right)
    }

    @Test("generated requests are well-formed and come from known profiles")
    func wellFormed() {
        var generator = LiveTrafficGenerator(seed: 1)
        let knownApps = Set(SampleData.appProfiles.map(\.app))
        for offset in 0..<500 {
            let entry = generator.next(at: start.addingTimeInterval(Double(offset)))
            #expect(knownApps.contains(entry.app))
            #expect((100...599).contains(entry.statusCode))
            #expect(entry.durationSeconds > 0)
            #expect(entry.requestBodySize >= 0)
            #expect(entry.responseBodySize >= 0)
            if entry.statusCode == 204 || entry.statusCode == 304 {
                #expect(entry.responseBodySize == 0)
            }
            if entry.method == .get {
                #expect(entry.requestBodySize == 0)
            }
        }
    }

    @Test("traffic spreads across every app and includes failures")
    func coverage() {
        var generator = LiveTrafficGenerator(seed: 99)
        let entries = generator.backfill(count: 2_000, endingAt: start, spanning: 600)
        #expect(Set(entries.map(\.app)).count == SampleData.appProfiles.count)
        #expect(entries.contains { $0.isFailure })
        #expect(entries.contains { !$0.isFailure })
    }

    @Test("backfill is evenly spaced, oldest first, ending at the given date")
    func backfillSpacing() {
        var generator = LiveTrafficGenerator(seed: 3)
        let entries = generator.backfill(count: 5, endingAt: start, spanning: 40)
        #expect(entries.map(\.timestamp) == [-40.0, -30, -20, -10, 0].map { start.addingTimeInterval($0) })
        #expect(generator.backfill(count: 0, endingAt: start, spanning: 40).isEmpty)
        #expect(generator.backfill(count: 1, endingAt: start, spanning: 40).map(\.timestamp) == [start.addingTimeInterval(-40)])
    }

    @Test("burst weight oscillates but never drops below 15% of base")
    func burstWeight() throws {
        let profile = try #require(SampleData.appProfiles.first)
        let samples = (0..<400).map { step in
            LiveTrafficGenerator.weight(of: profile, at: start.addingTimeInterval(Double(step) * 0.1))
        }
        let low = try #require(samples.min())
        let high = try #require(samples.max())
        #expect(low >= profile.weight * 0.15 - 1e-9)
        #expect(high <= profile.weight * 1.85 + 1e-9)
        #expect(high - low > profile.weight)
    }

    @Test("a single profile always wins the pick")
    func singleProfile() throws {
        let profile = try #require(SampleData.appProfiles.last)
        var generator = LiveTrafficGenerator(profiles: [profile], seed: 5)
        let entries = generator.backfill(count: 20, endingAt: start, spanning: 20)
        #expect(entries.allSatisfy { $0.app == profile.app })
    }

    // MARK: Log

    @Test("log keeps entries in order and evicts the oldest past capacity")
    func logEviction() {
        var generator = LiveTrafficGenerator(seed: 11)
        let entries = generator.backfill(count: 10, endingAt: start, spanning: 9)

        var log = TrafficLog(capacity: 4)
        for entry in entries {
            log.append(entry)
        }
        #expect(log.entries.map(\.id) == entries.suffix(4).map(\.id))

        log.append(contentsOf: Array(entries.prefix(2)))
        #expect(log.entries.count == 4)
        #expect(log.entries.suffix(2).map(\.id) == entries.prefix(2).map(\.id))

        log.removeAll()
        #expect(log.entries.isEmpty)
    }

    @Test("log initializer trims seed entries and clamps capacity")
    func logInit() {
        let seed = SampleData.capturedRequests
        #expect(TrafficLog(capacity: 3, entries: seed).entries.map(\.id) == seed.suffix(3).map(\.id))
        #expect(TrafficLog(capacity: -1, entries: seed).entries.isEmpty)
        #expect(TrafficLog(entries: seed).entries.count == seed.count)
    }

    // MARK: End to end

    @Test("live stream feeds a ranked dashboard")
    func endToEnd() throws {
        var generator = LiveTrafficGenerator(seed: 2024)
        var log = TrafficLog(capacity: 500)
        log.append(contentsOf: generator.backfill(count: 300, endingAt: start, spanning: 120))

        var now = start
        for _ in 0..<60 {
            now = now.addingTimeInterval(0.5)
            log.append(generator.next(at: now))
        }

        let perApp = log.entries.appStats(now: now)
        let summary = TrafficSummary(stats: perApp)
        #expect(summary.totalRequests == 360)
        #expect(perApp.reduce(0) { $0 + $1.requestCount } == log.entries.count)

        for order in AppStatsSortOrder.allCases {
            let ranked = perApp.ranked(by: order)
            #expect(ranked.count == perApp.count)
            for (lhs, rhs) in zip(ranked, ranked.dropFirst()) {
                #expect(!order.ranks(rhs, before: lhs), "\(order) out of order: \(rhs.app.displayName) before \(lhs.app.displayName)")
            }
        }

        let leader = try #require(perApp.ranked(by: .activity).first)
        #expect(leader.recentRequestCount == perApp.map(\.recentRequestCount).max())
    }
}
