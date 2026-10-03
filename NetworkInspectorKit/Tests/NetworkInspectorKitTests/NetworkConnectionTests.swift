import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("NetworkConnection")
struct NetworkConnectionTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let whatsApp = "A1B2C3D4E5.net.whatsapp.WhatsApp"
    private let safari = ".com.apple.mobilesafari"

    private func event(
        _ kind: FlowEvent.Kind,
        id: UUID,
        app: String? = "A1B2C3D4E5.net.whatsapp.WhatsApp",
        host: String? = "g.whatsapp.net",
        port: Int? = 443,
        blocked: Bool = false,
        received: Int = 0,
        sent: Int = 0,
        age: TimeInterval = 0
    ) -> FlowEvent {
        FlowEvent(
            flowID: id,
            kind: kind,
            timestamp: now.addingTimeInterval(-age),
            sourceAppIdentifier: app,
            remoteHost: host,
            remotePort: port,
            wasBlocked: blocked,
            bytesReceived: received,
            bytesSent: sent
        )
    }

    private func connection(host: String?, port: Int?) -> NetworkConnection {
        NetworkConnection(app: .unknown, remoteHost: host, remotePort: port, startedAt: now)
    }

    // MARK: Log

    @Test("a close updates the connection its open created")
    func openThenClose() throws {
        let id = UUID()
        var log = ConnectionLog()
        log.apply([event(.opened, id: id, age: 30)], directory: AppDirectory())

        let open = try #require(log.connections.first)
        #expect(open.state == .open)
        #expect(open.app.displayName == "WhatsApp")
        #expect(open.app.bundleIdentifier == "net.whatsapp.WhatsApp")
        #expect(open.durationSeconds == nil)
        #expect(open.totalBytes == 0)

        log.apply([event(.closed, id: id, received: 4_096, sent: 1_024, age: 10)], directory: AppDirectory())
        #expect(log.connections.count == 1)
        let closed = try #require(log.connections.first)
        #expect(closed.state == .closed)
        #expect(closed.durationSeconds == 20)
        #expect(closed.bytesReceived == 4_096)
        #expect(closed.bytesSent == 1_024)
        #expect(closed.startedAt == now.addingTimeInterval(-30))
    }

    @Test("a close without a seen open still records the bytes")
    func closeWithoutOpen() throws {
        var log = ConnectionLog()
        log.apply([event(.closed, id: UUID(), received: 100, sent: 50)], directory: AppDirectory())
        let connection = try #require(log.connections.first)
        #expect(connection.state == .closed)
        #expect(!connection.hasKnownStart)
        #expect(connection.durationSeconds == nil)
        #expect(connection.totalBytes == 150)
    }

    @Test("blocked connections count as failures")
    func blocked() throws {
        var log = ConnectionLog()
        log.apply([event(.opened, id: UUID(), blocked: true)], directory: AppDirectory())
        let connection = try #require(log.connections.first)
        #expect(connection.state == .blocked)
        #expect(connection.isFailure)
    }

    @Test("repeated opens are ignored")
    func duplicateOpen() {
        let id = UUID()
        var log = ConnectionLog()
        log.apply([event(.opened, id: id), event(.opened, id: id)], directory: AppDirectory())
        #expect(log.connections.count == 1)
    }

    @Test("the log drops the oldest connections past capacity")
    func capacity() {
        let ids = (0..<5).map { _ in UUID() }
        var log = ConnectionLog(capacity: 3)
        log.apply(ids.map { event(.opened, id: $0) }, directory: AppDirectory())
        #expect(log.connections.map(\.id) == Array(ids.suffix(3)))

        // Closing a kept connection still finds it after eviction.
        log.apply([event(.closed, id: ids[3], received: 10)], directory: AppDirectory())
        #expect(log.connections.count == 3)
        #expect(log.connections.first { $0.id == ids[3] }?.bytesReceived == 10)

        log.removeAll()
        #expect(log.connections.isEmpty)
        #expect(ConnectionLog(capacity: -1).capacity == 0)
    }

    @Test("apps are re-named when the directory learns more")
    func updateApps() throws {
        let unknownApp = "A1B2C3D4E5.com.example.weatherapp"
        var log = ConnectionLog()
        log.apply([event(.opened, id: UUID(), app: unknownApp)], directory: AppDirectory())
        #expect(log.connections.first?.app.displayName == "Weatherapp")

        let icon = try #require(URL(string: "https://example.com/icon.png"))
        let directory = AppDirectory(listings: [
            AppStoreListing(bundleIdentifier: "com.example.weatherapp", name: "Weather Pro", iconURL: icon)
        ])
        log.updateApps(using: directory)
        #expect(log.connections.first?.app.displayName == "Weather Pro")
        #expect(log.connections.first?.app.iconURL == icon)
    }

    // MARK: Connection

    @Test(
        "endpoint shows host and port",
        arguments: [
            ("g.whatsapp.net", 443, "g.whatsapp.net:443"),
            ("157.240.1.53", 5222, "157.240.1.53:5222"),
            ("2a03:2880:f21f::1", 443, "[2a03:2880:f21f::1]:443"),
            ("example.com", nil, "example.com"),
            (nil, 443, "Unknown host, port 443"),
            (nil, nil, "Unknown host")
        ] as [(String?, Int?, String)]
    )
    func endpoint(host: String?, port: Int?, expected: String) {
        #expect(connection(host: host, port: port).endpoint == expected)
    }

    @Test("bytes count toward speed when the connection closes")
    func trafficEntry() throws {
        let longLived = UUID()
        var log = ConnectionLog()
        log.apply(
            [
                event(.opened, id: longLived, age: 600),
                event(.closed, id: longLived, received: 60_000, sent: 6_000, age: 5),
                event(.opened, id: UUID(), age: 1)
            ],
            directory: AppDirectory()
        )

        let stats = try #require(TrafficStats.perApp(log.connections, now: now, rateWindow: 60).first)
        #expect(stats.requestCount == 2)
        // Only the connection opened in the window counts toward throughput.
        #expect(stats.recentRequestCount == 1)
        // The long-lived connection closed in the window, so its bytes count.
        #expect(stats.downloadBytesPerSecond == 1_000)
        #expect(stats.uploadBytesPerSecond == 100)
        // The still-open connection has no duration yet.
        #expect(stats.averageDurationSeconds == 595)
    }

    @Test("matching filters by host, app, transport and state")
    func matching() {
        let connections = [
            NetworkConnection(app: AppDirectory().app(forSourceAppIdentifier: whatsApp),
                              remoteHost: "g.whatsapp.net", remotePort: 443, startedAt: now),
            NetworkConnection(app: AppDirectory().app(forSourceAppIdentifier: safari),
                              remoteHost: "www.apple.com", remotePort: 443, transport: .udp,
                              startedAt: now.addingTimeInterval(-5), closedAt: now),
            NetworkConnection(app: AppDirectory().app(forSourceAppIdentifier: safari),
                              remoteHost: "tracker.example", remotePort: 443, wasBlocked: true,
                              startedAt: now.addingTimeInterval(-10))
        ]

        #expect(connections.matching(query: "").count == 3)
        #expect(connections.matching(query: "WHATSAPP").count == 1)
        #expect(connections.matching(query: "safari").count == 2)
        #expect(connections.matching(query: "udp").count == 1)
        #expect(connections.matching(query: ":443").count == 3)
        #expect(connections.matching(query: "", state: .open).count == 1)
        #expect(connections.matching(query: "", state: .closed).count == 1)
        #expect(connections.matching(query: "", state: .blocked).count == 1)
        #expect(connections.matching(query: "", app: connections[1].app).count == 2)
        #expect(connections.reversed().sortedByRecency().map(\.remoteHost) == connections.map(\.remoteHost))
    }
}
