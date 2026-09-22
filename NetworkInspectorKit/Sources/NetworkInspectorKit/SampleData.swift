import Foundation

/// Sample apps, traffic profiles and captured requests for previews, tests
/// and the simulated live feed.
public enum SampleData {
    public enum Apps {
        public static let courier = SourceApp(
            bundleIdentifier: "com.example.courier",
            displayName: "Courier",
            symbolName: "bubble.left.and.bubble.right.fill"
        )
        public static let frame = SourceApp(
            bundleIdentifier: "com.example.frame",
            displayName: "Frame",
            symbolName: "camera.fill"
        )
        public static let orbit = SourceApp(
            bundleIdentifier: "com.example.orbit",
            displayName: "Orbit Maps",
            symbolName: "map.fill"
        )
        public static let nimbus = SourceApp(
            bundleIdentifier: "com.example.nimbus",
            displayName: "Nimbus",
            symbolName: "cloud.sun.fill"
        )
        public static let tempo = SourceApp(
            bundleIdentifier: "com.example.tempo",
            displayName: "Tempo",
            symbolName: "music.note"
        )
        public static let ledger = SourceApp(
            bundleIdentifier: "com.example.ledger",
            displayName: "Ledger",
            symbolName: "creditcard.fill"
        )
        public static let stride = SourceApp(
            bundleIdentifier: "com.example.stride",
            displayName: "Stride",
            symbolName: "figure.run"
        )

        public static let all = [courier, frame, orbit, nimbus, tempo, ledger, stride]
    }

    public static let appProfiles: [AppTrafficProfile] = [
        AppTrafficProfile(
            app: Apps.courier,
            weight: 5,
            endpoints: [
                .init(.get, "https://chat.courier.example/v2/sync"),
                .init(.post, "https://chat.courier.example/v2/messages"),
                .init(.get, "https://chat.courier.example/v2/presence")
            ],
            baseLatencySeconds: 0.09,
            failureRate: 0.02,
            typicalResponseSize: 2_400,
            burstPhase: 0
        ),
        AppTrafficProfile(
            app: Apps.frame,
            weight: 2,
            endpoints: [
                .init(.put, "https://upload.frame.example/v1/photos"),
                .init(.get, "https://cdn.frame.example/thumbs/batch"),
                .init(.get, "https://api.frame.example/v1/albums")
            ],
            baseLatencySeconds: 0.6,
            failureRate: 0.04,
            typicalResponseSize: 480_000,
            burstPhase: 0.3
        ),
        AppTrafficProfile(
            app: Apps.orbit,
            weight: 3,
            endpoints: [
                .init(.get, "https://tiles.orbit.example/v4/12/2048/1361.pbf"),
                .init(.get, "https://api.orbit.example/v1/route"),
                .init(.get, "https://api.orbit.example/v1/search?q=coffee")
            ],
            baseLatencySeconds: 0.14,
            failureRate: 0.03,
            typicalResponseSize: 36_000,
            burstPhase: 0.55
        ),
        AppTrafficProfile(
            app: Apps.nimbus,
            weight: 1,
            endpoints: [
                .init(.get, "https://api.nimbus.example/v3/forecast"),
                .init(.get, "https://api.nimbus.example/v3/radar/latest")
            ],
            baseLatencySeconds: 0.22,
            failureRate: 0.01,
            typicalResponseSize: 9_500,
            burstPhase: 0.8
        ),
        AppTrafficProfile(
            app: Apps.tempo,
            weight: 2.5,
            endpoints: [
                .init(.get, "https://stream.tempo.example/v1/segments/1842.m4s"),
                .init(.get, "https://api.tempo.example/v1/queue"),
                .init(.post, "https://api.tempo.example/v1/scrobble")
            ],
            baseLatencySeconds: 0.12,
            failureRate: 0.02,
            typicalResponseSize: 180_000,
            burstPhase: 0.15
        ),
        AppTrafficProfile(
            app: Apps.ledger,
            weight: 0.8,
            endpoints: [
                .init(.get, "https://api.ledger.example/v2/accounts"),
                .init(.post, "https://api.ledger.example/v2/transfers"),
                .init(.get, "https://api.ledger.example/v2/transactions?limit=50")
            ],
            baseLatencySeconds: 0.45,
            failureRate: 0.12,
            typicalResponseSize: 6_200,
            burstPhase: 0.65
        ),
        AppTrafficProfile(
            app: Apps.stride,
            weight: 1.2,
            endpoints: [
                .init(.post, "https://api.stride.example/v1/workouts"),
                .init(.patch, "https://api.stride.example/v1/goals/7"),
                .init(.delete, "https://api.stride.example/v1/drafts/31")
            ],
            baseLatencySeconds: 0.3,
            failureRate: 0.06,
            typicalResponseSize: 1_100,
            burstPhase: 0.4
        )
    ]

    public static let capturedRequests: [CapturedRequest] = [
        CapturedRequest(
            app: Apps.courier,
            method: .get,
            url: "https://api.example.com/v1/users/42",
            statusCode: 200,
            durationSeconds: 0.084,
            requestBodySize: 0,
            responseBodySize: 1_842,
            timestamp: Date(timeIntervalSinceNow: -12)
        ),
        CapturedRequest(
            app: Apps.courier,
            method: .post,
            url: "https://api.example.com/v1/sessions",
            statusCode: 201,
            durationSeconds: 0.312,
            requestBodySize: 256,
            responseBodySize: 128,
            timestamp: Date(timeIntervalSinceNow: -48)
        ),
        CapturedRequest(
            app: Apps.frame,
            method: .get,
            url: "https://cdn.example.com/assets/logo.png",
            statusCode: 304,
            durationSeconds: 0.021,
            requestBodySize: 0,
            responseBodySize: 0,
            timestamp: Date(timeIntervalSinceNow: -90)
        ),
        CapturedRequest(
            app: Apps.stride,
            method: .patch,
            url: "https://api.example.com/v1/users/42/preferences",
            statusCode: 422,
            durationSeconds: 0.156,
            requestBodySize: 512,
            responseBodySize: 340,
            timestamp: Date(timeIntervalSinceNow: -160)
        ),
        CapturedRequest(
            app: Apps.ledger,
            method: .get,
            url: "https://api.example.com/v1/reports/summary",
            statusCode: 500,
            durationSeconds: 4.7,
            requestBodySize: 0,
            responseBodySize: 96,
            timestamp: Date(timeIntervalSinceNow: -240)
        ),
        CapturedRequest(
            app: Apps.orbit,
            method: .delete,
            url: "https://api.example.com/v1/cache/entries/9",
            statusCode: 204,
            durationSeconds: 0.043,
            requestBodySize: 0,
            responseBodySize: 0,
            timestamp: Date(timeIntervalSinceNow: -310)
        ),
        CapturedRequest(
            app: Apps.nimbus,
            method: .get,
            url: "https://api.example.com/v1/nonexistent",
            statusCode: 404,
            durationSeconds: 0.067,
            requestBodySize: 0,
            responseBodySize: 58,
            timestamp: Date(timeIntervalSinceNow: -400)
        )
    ]
}
