import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("TrafficStats")
struct TrafficStatsTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private let alpha = SourceApp(bundleIdentifier: "com.test.alpha", displayName: "Alpha")
    private let bravo = SourceApp(bundleIdentifier: "com.test.bravo", displayName: "Bravo")
    private let charlie = SourceApp(bundleIdentifier: "com.test.charlie", displayName: "Charlie")

    private func request(
        _ app: SourceApp,
        status: Int = 200,
        duration: Double = 0.1,
        sent: Int = 0,
        received: Int = 100,
        age: TimeInterval = 1
    ) -> CapturedRequest {
        CapturedRequest(
            app: app,
            method: .get,
            url: "https://\(app.bundleIdentifier).example/",
            statusCode: status,
            durationSeconds: duration,
            requestBodySize: sent,
            responseBodySize: received,
            timestamp: now.addingTimeInterval(-age)
        )
    }

    private func stats(
        _ app: SourceApp,
        requests: Int = 1,
        failures: Int = 0,
        bytes: Int = 0,
        latency: Double = 0.1,
        recent: Int = 0
    ) -> AppTrafficStats {
        AppTrafficStats(
            app: app,
            requestCount: requests,
            failureCount: failures,
            bytesSent: 0,
            bytesReceived: bytes,
            averageDurationSeconds: latency,
            lastActivity: now,
            recentRequestCount: recent,
            rateWindow: 60,
            activity: []
        )
    }

    // MARK: Aggregation

    @Test("groups entries by app and aggregates totals")
    func aggregatesPerApp() throws {
        let entries = [
            request(alpha, status: 200, duration: 0.1, sent: 10, received: 100),
            request(alpha, status: 500, duration: 0.3, sent: 20, received: 200),
            request(bravo, status: 404, duration: 1.0, received: 50)
        ]

        let result = TrafficStats.perApp(entries, now: now)
        #expect(result.map(\.app) == [alpha, bravo])

        let a = try #require(result.first)
        #expect(a.requestCount == 2)
        #expect(a.failureCount == 1)
        #expect(a.bytesSent == 30)
        #expect(a.bytesReceived == 300)
        #expect(a.totalBytes == 330)
        #expect(abs(a.averageDurationSeconds - 0.2) < 1e-9)
        #expect(a.errorRate == 0.5)

        let b = try #require(result.last)
        #expect(b.requestCount == 1)
        #expect(b.errorRate == 1)
    }

    @Test("empty input yields no stats")
    func emptyInput() {
        #expect(TrafficStats.perApp([], now: now).isEmpty)
        #expect(TrafficSummary(stats: []).totalRequests == 0)
        #expect(TrafficSummary(stats: []).errorRate == 0)
    }

    @Test("throughput only counts requests inside the trailing window")
    func throughputWindow() throws {
        let entries = [
            request(alpha, age: 0),
            request(alpha, age: 10),
            request(alpha, age: 59.9),
            request(alpha, age: 60),   // just outside
            request(alpha, age: 300),  // old
            request(alpha, age: -5)    // future, ignored
        ]
        let result = try #require(TrafficStats.perApp(entries, now: now, rateWindow: 60).first)
        #expect(result.requestCount == 6)
        #expect(result.recentRequestCount == 3)
        #expect(result.requestsPerMinute == 3)
        #expect(result.isActive)
        #expect(result.lastActivity == now.addingTimeInterval(5))
    }

    @Test("requests per minute normalizes shorter windows")
    func rateNormalization() throws {
        let entries = (0..<5).map { request(alpha, age: Double($0)) }
        let result = try #require(TrafficStats.perApp(entries, now: now, rateWindow: 30).first)
        #expect(result.requestsPerMinute == 10)
    }

    @Test("an app with only old traffic is inactive")
    func inactiveApp() throws {
        let result = try #require(TrafficStats.perApp([request(alpha, age: 600)], now: now).first)
        #expect(!result.isActive)
        #expect(result.requestsPerMinute == 0)
        #expect(result.activity.allSatisfy { $0 == 0 })
    }

    @Test("activity buckets place timestamps oldest first")
    func activityBuckets() {
        let timestamps = [0.0, 0.5, 1.5, 5.9, 6.0, -1].map { now.addingTimeInterval(-$0) }
        let buckets = TrafficStats.activityBuckets(timestamps: timestamps, now: now, window: 6, bucketCount: 3)
        // Buckets cover ages [4,6), [2,4), [0,2); age 6 and the future are dropped.
        #expect(buckets == [1, 0, 3])
    }

    @Test("activity buckets handle degenerate sizes")
    func activityBucketsDegenerate() {
        #expect(TrafficStats.activityBuckets(timestamps: [now], now: now, window: 60, bucketCount: 0).isEmpty)
        #expect(TrafficStats.activityBuckets(timestamps: [now], now: now, window: 0, bucketCount: 2) == [0, 0])
    }

    @Test("apps sharing a bundle identifier are merged")
    func mergesByBundleIdentifier() {
        let renamed = SourceApp(bundleIdentifier: alpha.bundleIdentifier, displayName: "Alpha 2")
        let result = TrafficStats.perApp([request(alpha), request(renamed)], now: now)
        #expect(result.count == 1)
        #expect(result.first?.requestCount == 2)
    }

    @Test("sequence convenience matches TrafficStats.perApp")
    func sequenceConvenience() {
        let entries = [request(alpha), request(bravo, status: 500)]
        #expect(entries.appStats(now: now) == TrafficStats.perApp(entries, now: now))
    }

    // MARK: Ranking

    @Test("ranks by live activity, highest first")
    func rankByActivity() {
        let list = [stats(alpha, recent: 2), stats(bravo, recent: 9), stats(charlie, recent: 5)]
        #expect(list.ranked(by: .activity).map(\.app) == [bravo, charlie, alpha])
    }

    @Test("ranks by total requests, highest first")
    func rankByRequests() {
        let list = [stats(alpha, requests: 3), stats(bravo, requests: 1), stats(charlie, requests: 7)]
        #expect(list.ranked(by: .requests).map(\.app) == [charlie, alpha, bravo])
    }

    @Test("ranks by data transferred, highest first")
    func rankByData() {
        let list = [stats(alpha, bytes: 10), stats(bravo, bytes: 5_000), stats(charlie, bytes: 400)]
        #expect(list.ranked(by: .data).map(\.app) == [bravo, charlie, alpha])
    }

    @Test("ranks by error rate, then failure count")
    func rankByErrors() {
        let list = [
            stats(alpha, requests: 10, failures: 1),   // 10%
            stats(bravo, requests: 4, failures: 2),    // 50%
            stats(charlie, requests: 20, failures: 2)  // 10%, more failures
        ]
        #expect(list.ranked(by: .errors).map(\.app) == [bravo, charlie, alpha])
    }

    @Test("ranks by latency, slowest first")
    func rankByLatency() {
        let list = [stats(alpha, latency: 0.2), stats(bravo, latency: 0.05), stats(charlie, latency: 1.4)]
        #expect(list.ranked(by: .latency).map(\.app) == [charlie, alpha, bravo])
    }

    @Test("ranks by name alphabetically, case-insensitively")
    func rankByName() {
        let lower = SourceApp(bundleIdentifier: "com.test.aardvark", displayName: "aardvark")
        let list = [stats(charlie), stats(bravo), stats(lower), stats(alpha)]
        #expect(list.ranked(by: .name).map(\.app) == [lower, alpha, bravo, charlie])
    }

    @Test("ties fall back to name so ordering is stable", arguments: AppStatsSortOrder.allCases)
    func tiesBreakByName(order: AppStatsSortOrder) {
        let list = [stats(charlie), stats(alpha), stats(bravo)]
        #expect(list.ranked(by: order).map(\.app) == [alpha, bravo, charlie])
        #expect(list.reversed().ranked(by: order).map(\.app) == [alpha, bravo, charlie])
    }

    @Test("ranking is a strict ordering", arguments: AppStatsSortOrder.allCases)
    func strictOrdering(order: AppStatsSortOrder) {
        let a = stats(alpha, requests: 3, failures: 1, bytes: 9, latency: 0.3, recent: 2)
        #expect(!order.ranks(a, before: a))
        let b = stats(bravo, requests: 5, failures: 0, bytes: 1, latency: 0.1, recent: 4)
        #expect(order.ranks(a, before: b) != order.ranks(b, before: a))
    }

    @Test("every sort order has a distinct label")
    func sortLabels() {
        let labels = AppStatsSortOrder.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }

    // MARK: Headlines & summary

    @Test("headline features the metric being ranked")
    func headlines() {
        let s = AppTrafficStats(
            app: alpha,
            requestCount: 40,
            failureCount: 5,
            bytesSent: 512,
            bytesReceived: 1_024,
            averageDurationSeconds: 0.25,
            lastActivity: now,
            recentRequestCount: 12,
            rateWindow: 60,
            activity: []
        )
        #expect(s.headline(for: .activity) == StatHeadline(value: "12/min", caption: "per min"))
        #expect(s.headline(for: .requests) == StatHeadline(value: "40", caption: "requests"))
        #expect(s.headline(for: .data) == StatHeadline(value: "1.5 KB", caption: "transferred"))
        #expect(s.headline(for: .errors) == StatHeadline(value: "13%", caption: "errors"))
        #expect(s.headline(for: .latency) == StatHeadline(value: "250 ms", caption: "avg latency"))
        #expect(stats(alpha, requests: 1).headline(for: .requests).caption == "request")
    }

    @Test("summary totals every app and sums activity")
    func summary() throws {
        let entries = [
            request(alpha, status: 500, sent: 10, received: 90, age: 1),
            request(alpha, age: 30),
            request(bravo, status: 404, received: 100, age: 2),
            request(charlie, age: 500)
        ]
        let perApp = TrafficStats.perApp(entries, now: now, rateWindow: 60, bucketCount: 4)
        let summary = TrafficSummary(stats: perApp)

        #expect(summary.totalRequests == 4)
        #expect(summary.failureCount == 2)
        #expect(summary.errorRate == 0.5)
        #expect(summary.totalBytes == 400)
        #expect(summary.activeAppCount == 2)
        #expect(summary.requestsPerMinute == 3)
        #expect(summary.activity == [0, 1, 0, 2])

        let alphaStats = try #require(perApp.first { $0.app == alpha })
        #expect(summary.share(of: alphaStats) == 0.5)
    }

    @Test("source app hue is stable and in range")
    func tintHue() {
        for app in SampleData.Apps.all {
            #expect((0..<1).contains(app.tintHue))
            #expect(app.tintHue == SourceApp(bundleIdentifier: app.bundleIdentifier, displayName: "x").tintHue)
        }
        let hues = Set(SampleData.Apps.all.map(\.tintHue))
        #expect(hues.count > 1)
    }
}
