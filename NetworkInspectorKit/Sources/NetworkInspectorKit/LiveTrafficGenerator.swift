import Foundation

/// A small, fast, seedable PRNG (SplitMix64) so generated traffic is
/// reproducible in tests and previews.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

/// How a simulated app behaves on the network.
public struct AppTrafficProfile: Sendable {
    public struct Endpoint: Sendable {
        public let method: HTTPMethod
        public let url: String

        public init(_ method: HTTPMethod, _ url: String) {
            self.method = method
            self.url = url
        }
    }

    public let app: SourceApp
    /// Relative share of traffic this app produces on average.
    public let weight: Double
    public let endpoints: [Endpoint]
    public let baseLatencySeconds: Double
    /// Probability in `0...1` that a request fails.
    public let failureRate: Double
    public let typicalResponseSize: Int
    /// Offset (in cycles) of this app's burst pattern, so apps peak at
    /// different times and the ranking visibly shifts.
    public let burstPhase: Double

    public init(
        app: SourceApp,
        weight: Double,
        endpoints: [Endpoint],
        baseLatencySeconds: Double,
        failureRate: Double,
        typicalResponseSize: Int,
        burstPhase: Double
    ) {
        self.app = app
        self.weight = weight
        self.endpoints = endpoints
        self.baseLatencySeconds = baseLatencySeconds
        self.failureRate = failureRate
        self.typicalResponseSize = typicalResponseSize
        self.burstPhase = burstPhase
    }
}

/// Produces a believable, deterministic stream of captured requests across
/// several apps, for the live dashboard until real capture is wired up.
public struct LiveTrafficGenerator: Sendable {
    /// Seconds for one full burst cycle of an app's traffic.
    public static let burstPeriod: TimeInterval = 40
    private static let failureCodes = [400, 401, 404, 422, 429, 500, 502, 503]

    public let profiles: [AppTrafficProfile]
    private var rng: SeededRandomNumberGenerator

    public init(profiles: [AppTrafficProfile] = SampleData.appProfiles, seed: UInt64 = 0x5eed) {
        precondition(!profiles.isEmpty, "LiveTrafficGenerator needs at least one profile")
        self.profiles = profiles
        rng = SeededRandomNumberGenerator(seed: seed)
    }

    /// The instantaneous weight of `profile` at `date`: its base weight
    /// modulated by a slow sine wave, never dropping below 15% of base.
    public static func weight(of profile: AppTrafficProfile, at date: Date) -> Double {
        let cycles = date.timeIntervalSinceReferenceDate / burstPeriod + profile.burstPhase
        return profile.weight * (1 + 0.85 * sin(cycles * 2 * .pi))
    }

    /// Generates one request stamped at `date`.
    public mutating func next(at date: Date) -> CapturedRequest {
        let profile = pickProfile(at: date)
        let endpoint = profile.endpoints.randomElement(using: &rng)
            ?? AppTrafficProfile.Endpoint(.get, "https://example.com/")

        let failed = Double.random(in: 0..<1, using: &rng) < profile.failureRate
        let statusCode = failed
            ? Self.failureCodes.randomElement(using: &rng) ?? 500
            : successCode(for: endpoint.method)

        var latency = profile.baseLatencySeconds * Double.random(in: 0.5...1.8, using: &rng)
        if Double.random(in: 0..<1, using: &rng) < 0.05 {
            latency *= 4
        }

        let hasBody = statusCode != 204 && statusCode != 304
        let responseSize = hasBody
            ? Int(Double(profile.typicalResponseSize) * Double.random(in: 0.3...1.7, using: &rng))
            : 0
        let requestSize: Int = switch endpoint.method {
        case .get, .head, .options, .delete: 0
        case .post, .put, .patch: Int.random(in: 64...2_048, using: &rng)
        }

        return CapturedRequest(
            app: profile.app,
            method: endpoint.method,
            url: endpoint.url,
            statusCode: statusCode,
            durationSeconds: latency,
            requestBodySize: requestSize,
            responseBodySize: responseSize,
            timestamp: date
        )
    }

    /// Generates `count` requests evenly spread over the `span` seconds
    /// ending at `end`, oldest first, to seed a dashboard with history.
    public mutating func backfill(count: Int, endingAt end: Date, spanning span: TimeInterval) -> [CapturedRequest] {
        guard count > 0 else { return [] }
        let step = count > 1 ? span / Double(count - 1) : 0
        return (0..<count).map { index in
            next(at: end.addingTimeInterval(-span + step * Double(index)))
        }
    }

    private mutating func pickProfile(at date: Date) -> AppTrafficProfile {
        let weights = profiles.map { Self.weight(of: $0, at: date) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return profiles[0] }

        var target = Double.random(in: 0..<total, using: &rng)
        for (profile, weight) in zip(profiles, weights) {
            if target < weight { return profile }
            target -= weight
        }
        return profiles[profiles.count - 1]
    }

    private mutating func successCode(for method: HTTPMethod) -> Int {
        switch method {
        case .get:
            Double.random(in: 0..<1, using: &rng) < 0.1 ? 304 : 200
        case .post: 201
        case .delete: 204
        case .put, .patch, .head, .options: 200
        }
    }
}
