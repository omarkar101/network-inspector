import Foundation

/// Aggregated, point-in-time traffic statistics for a single app.
public struct AppTrafficStats: Sendable, Identifiable, Hashable {
    public let app: SourceApp
    public let requestCount: Int
    public let failureCount: Int
    public let bytesSent: Int
    public let bytesReceived: Int
    public let averageDurationSeconds: Double
    public let lastActivity: Date
    /// Requests whose timestamp falls inside the trailing rate window.
    public let recentRequestCount: Int
    /// Length of the trailing window used for `recentRequestCount` and `activity`.
    public let rateWindow: TimeInterval
    /// Request counts per time bucket across the rate window, oldest first.
    public let activity: [Int]
    /// Request body bytes sent inside the trailing rate window.
    public let recentBytesSent: Int
    /// Response body bytes received inside the trailing rate window.
    public let recentBytesReceived: Int

    public var id: String { app.id }

    public init(
        app: SourceApp,
        requestCount: Int,
        failureCount: Int,
        bytesSent: Int,
        bytesReceived: Int,
        averageDurationSeconds: Double,
        lastActivity: Date,
        recentRequestCount: Int,
        rateWindow: TimeInterval,
        activity: [Int],
        recentBytesSent: Int = 0,
        recentBytesReceived: Int = 0
    ) {
        self.app = app
        self.requestCount = requestCount
        self.failureCount = failureCount
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.averageDurationSeconds = averageDurationSeconds
        self.lastActivity = lastActivity
        self.recentRequestCount = recentRequestCount
        self.rateWindow = rateWindow
        self.activity = activity
        self.recentBytesSent = recentBytesSent
        self.recentBytesReceived = recentBytesReceived
    }

    public var totalBytes: Int { bytesSent + bytesReceived }

    /// Fraction of requests that failed, in `0...1`.
    public var errorRate: Double {
        requestCount == 0 ? 0 : Double(failureCount) / Double(requestCount)
    }

    /// Throughput over the trailing rate window, normalized to one minute.
    public var requestsPerMinute: Double {
        rateWindow > 0 ? Double(recentRequestCount) * 60 / rateWindow : 0
    }

    /// Current download speed: bytes received per second over the rate window.
    public var downloadBytesPerSecond: Double {
        rateWindow > 0 ? Double(recentBytesReceived) / rateWindow : 0
    }

    /// Current upload speed: bytes sent per second over the rate window.
    public var uploadBytesPerSecond: Double {
        rateWindow > 0 ? Double(recentBytesSent) / rateWindow : 0
    }

    /// Combined download and upload speed, in bytes per second.
    public var totalBytesPerSecond: Double {
        downloadBytesPerSecond + uploadBytesPerSecond
    }

    /// Whether the app issued any request inside the trailing rate window.
    public var isActive: Bool { recentRequestCount > 0 }

    /// The value to feature for this app when the list is ranked by `order`.
    public func headline(for order: AppStatsSortOrder) -> StatHeadline {
        switch order {
        case .activity, .name:
            StatHeadline(value: Formatting.rate(perMinute: requestsPerMinute), caption: "per min")
        case .requests:
            StatHeadline(value: "\(requestCount)", caption: requestCount == 1 ? "request" : "requests")
        case .speed:
            StatHeadline(value: Formatting.speed(bytesPerSecond: totalBytesPerSecond), caption: "down + up")
        case .data:
            StatHeadline(value: Formatting.byteSize(totalBytes), caption: "transferred")
        case .errors:
            StatHeadline(value: Formatting.percent(errorRate), caption: "errors")
        case .latency:
            StatHeadline(value: Formatting.duration(seconds: averageDurationSeconds), caption: "avg latency")
        }
    }
}

/// A formatted value plus a short caption, e.g. "12/min" + "per min".
public struct StatHeadline: Sendable, Hashable {
    public let value: String
    public let caption: String

    public init(value: String, caption: String) {
        self.value = value
        self.caption = caption
    }
}

/// Orders in which the per-app list can be ranked.
public enum AppStatsSortOrder: String, Sendable, CaseIterable, Identifiable {
    case activity
    case requests
    case speed
    case data
    case errors
    case latency
    case name

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .activity: "Live"
        case .requests: "Requests"
        case .speed: "Speed"
        case .data: "Data"
        case .errors: "Errors"
        case .latency: "Latency"
        case .name: "Name"
        }
    }

    /// Whether `lhs` ranks ahead of `rhs`. Metrics rank highest first; ties
    /// (and `.name`) fall back to the app name, then bundle identifier, so the
    /// order is total and the list never jitters between equal rows.
    public func ranks(_ lhs: AppTrafficStats, before rhs: AppTrafficStats) -> Bool {
        let primary: ComparisonResult = switch self {
        case .activity: Self.descending(lhs.recentRequestCount, rhs.recentRequestCount)
        case .requests: Self.descending(lhs.requestCount, rhs.requestCount)
        case .speed: Self.descending(lhs.totalBytesPerSecond, rhs.totalBytesPerSecond)
        case .data: Self.descending(lhs.totalBytes, rhs.totalBytes)
        case .errors:
            lhs.errorRate == rhs.errorRate
                ? Self.descending(lhs.failureCount, rhs.failureCount)
                : Self.descending(lhs.errorRate, rhs.errorRate)
        case .latency: Self.descending(lhs.averageDurationSeconds, rhs.averageDurationSeconds)
        case .name: .orderedSame
        }
        if primary != .orderedSame {
            return primary == .orderedAscending
        }

        let byName = lhs.app.displayName.localizedCaseInsensitiveCompare(rhs.app.displayName)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.app.bundleIdentifier < rhs.app.bundleIdentifier
    }

    private static func descending<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs > rhs ? .orderedAscending : .orderedDescending
    }
}

extension Sequence<AppTrafficStats> {
    /// Stats ranked according to `order`, first place first.
    public func ranked(by order: AppStatsSortOrder) -> [AppTrafficStats] {
        sorted { order.ranks($0, before: $1) }
    }
}

/// Totals across every app, for the dashboard header.
public struct TrafficSummary: Sendable, Hashable {
    public let totalRequests: Int
    public let failureCount: Int
    public let totalBytes: Int
    public let activeAppCount: Int
    public let requestsPerMinute: Double
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    /// Element-wise sum of every app's activity buckets, oldest first.
    public let activity: [Int]

    public init(stats: [AppTrafficStats]) {
        totalRequests = stats.reduce(0) { $0 + $1.requestCount }
        failureCount = stats.reduce(0) { $0 + $1.failureCount }
        totalBytes = stats.reduce(0) { $0 + $1.totalBytes }
        activeAppCount = stats.filter { $0.isActive }.count
        requestsPerMinute = stats.reduce(0) { $0 + $1.requestsPerMinute }
        downloadBytesPerSecond = stats.reduce(0) { $0 + $1.downloadBytesPerSecond }
        uploadBytesPerSecond = stats.reduce(0) { $0 + $1.uploadBytesPerSecond }

        let bucketCount = stats.map(\.activity.count).max() ?? 0
        var activity = Array(repeating: 0, count: bucketCount)
        for app in stats {
            for (index, count) in app.activity.enumerated() {
                activity[index] += count
            }
        }
        self.activity = activity
        self.recentBytesSent = recentBytesSent
        self.recentBytesReceived = recentBytesReceived
    }

    public var errorRate: Double {
        totalRequests == 0 ? 0 : Double(failureCount) / Double(totalRequests)
    }

    /// The fraction of all requests issued by `stats`' app, in `0...1`.
    public func share(of stats: AppTrafficStats) -> Double {
        totalRequests == 0 ? 0 : Double(stats.requestCount) / Double(totalRequests)
    }
}

public enum TrafficStats {
    public static let defaultRateWindow: TimeInterval = 60
    public static let defaultBucketCount = 20

    /// Aggregates entries into one `AppTrafficStats` per app (keyed by bundle
    /// identifier), ordered by app name. Totals cover every entry; throughput,
    /// upload/download speed and activity only cover the trailing `rateWindow`
    /// ending at `now`.
    public static func perApp(
        _ entries: [CapturedRequest],
        now: Date,
        rateWindow: TimeInterval = defaultRateWindow,
        bucketCount: Int = defaultBucketCount
    ) -> [AppTrafficStats] {
        let groups = Dictionary(grouping: entries, by: \.app.bundleIdentifier)

        let stats = groups.values.compactMap { group -> AppTrafficStats? in
            guard let first = group.first else { return nil }
            let timestamps = group.map(\.timestamp)
            let recent = group.filter { isInWindow($0.timestamp, now: now, window: rateWindow) }
            let totalDuration = group.reduce(0) { $0 + $1.durationSeconds }
            return AppTrafficStats(
                app: first.app,
                requestCount: group.count,
                failureCount: group.filter { $0.isFailure }.count,
                bytesSent: group.reduce(0) { $0 + $1.requestBodySize },
                bytesReceived: group.reduce(0) { $0 + $1.responseBodySize },
                averageDurationSeconds: totalDuration / Double(group.count),
                lastActivity: timestamps.max() ?? first.timestamp,
                recentRequestCount: recent.count,
                rateWindow: rateWindow,
                activity: activityBuckets(timestamps: timestamps, now: now, window: rateWindow, bucketCount: bucketCount),
                recentBytesSent: recent.reduce(0) { $0 + $1.requestBodySize },
                recentBytesReceived: recent.reduce(0) { $0 + $1.responseBodySize }
            )
        }
        return stats.ranked(by: .name)
    }

    /// Counts timestamps into `bucketCount` equal buckets spanning the window
    /// `(now - window, now]`, oldest bucket first. Timestamps outside the
    /// window (including ones in the future) are ignored.
    public static func activityBuckets(
        timestamps: [Date],
        now: Date,
        window: TimeInterval,
        bucketCount: Int
    ) -> [Int] {
        guard bucketCount > 0 else { return [] }
        var buckets = Array(repeating: 0, count: bucketCount)
        guard window > 0 else { return buckets }

        let bucketWidth = window / Double(bucketCount)
        for timestamp in timestamps where isInWindow(timestamp, now: now, window: window) {
            let age = now.timeIntervalSince(timestamp)
            let offset = min(Int(age / bucketWidth), bucketCount - 1)
            buckets[bucketCount - 1 - offset] += 1
        }
        return buckets
    }

    private static func isInWindow(_ timestamp: Date, now: Date, window: TimeInterval) -> Bool {
        let age = now.timeIntervalSince(timestamp)
        return age >= 0 && age < window
    }
}

extension Sequence<CapturedRequest> {
    /// Per-app statistics for these entries; see `TrafficStats.perApp`.
    public func appStats(
        now: Date,
        rateWindow: TimeInterval = TrafficStats.defaultRateWindow,
        bucketCount: Int = TrafficStats.defaultBucketCount
    ) -> [AppTrafficStats] {
        TrafficStats.perApp(Array(self), now: now, rateWindow: rateWindow, bucketCount: bucketCount)
    }
}
