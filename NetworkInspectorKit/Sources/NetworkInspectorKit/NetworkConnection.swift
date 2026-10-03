import Foundation

/// Where a captured connection stands.
public enum ConnectionState: String, Sendable, CaseIterable, Hashable {
    case open
    case closed
    /// Dropped by the content filter because its app is blocked.
    case blocked

    public var label: String {
        switch self {
        case .open: "Open"
        case .closed: "Closed"
        case .blocked: "Blocked"
        }
    }
}

/// One network connection an app made, as captured on the device by the
/// content filter. Assembled from its `FlowEvent`s by `ConnectionLog`.
///
/// The filter sees connections, not HTTP requests: traffic is encrypted, so
/// there is a remote host and port but no URL path, method or status code.
public struct NetworkConnection: Sendable, Identifiable, Hashable {
    public let id: UUID
    /// The app that made the connection, as named by an `AppDirectory`.
    public internal(set) var app: SourceApp
    /// The raw identifier the filter reported, kept so the app can be
    /// re-named once more is known about it.
    public let sourceAppIdentifier: String?
    public let remoteHost: String?
    public let remotePort: Int?
    public let transport: FlowEvent.Transport
    public let isInbound: Bool
    public let wasBlocked: Bool
    /// When the connection opened, or when it closed if its opening wasn't seen.
    public let startedAt: Date
    /// Whether `startedAt` is when the connection really opened.
    public let hasKnownStart: Bool
    public internal(set) var closedAt: Date?
    /// Bytes sent and received. Only known once the connection closes.
    public internal(set) var bytesSent: Int
    public internal(set) var bytesReceived: Int

    public init(
        id: UUID = UUID(),
        app: SourceApp,
        sourceAppIdentifier: String? = nil,
        remoteHost: String?,
        remotePort: Int?,
        transport: FlowEvent.Transport = .tcp,
        isInbound: Bool = false,
        wasBlocked: Bool = false,
        startedAt: Date,
        hasKnownStart: Bool = true,
        closedAt: Date? = nil,
        bytesSent: Int = 0,
        bytesReceived: Int = 0
    ) {
        self.id = id
        self.app = app
        self.sourceAppIdentifier = sourceAppIdentifier
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.transport = transport
        self.isInbound = isInbound
        self.wasBlocked = wasBlocked
        self.startedAt = startedAt
        self.hasKnownStart = hasKnownStart
        self.closedAt = closedAt
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }

    /// A connection from its first event: opened, or already closed when
    /// its opening wasn't seen.
    public init(event: FlowEvent, app: SourceApp) {
        let closed = event.kind == .closed
        self.init(
            id: event.flowID,
            app: app,
            sourceAppIdentifier: event.sourceAppIdentifier,
            remoteHost: event.remoteHost,
            remotePort: event.remotePort,
            transport: event.transport,
            isInbound: event.isInbound,
            wasBlocked: event.wasBlocked,
            startedAt: event.timestamp,
            hasKnownStart: !closed,
            closedAt: closed ? event.timestamp : nil,
            bytesSent: closed ? event.bytesSent : 0,
            bytesReceived: closed ? event.bytesReceived : 0
        )
    }

    public var state: ConnectionState {
        if wasBlocked { return .blocked }
        return closedAt == nil ? .open : .closed
    }

    /// How long the connection was open. Nil while it's still open, or if
    /// its opening wasn't seen.
    public var durationSeconds: Double? {
        guard hasKnownStart, let closedAt else { return nil }
        return max(closedAt.timeIntervalSince(startedAt), 0)
    }

    public var totalBytes: Int { bytesSent + bytesReceived }

    /// The remote end, e.g. "g.whatsapp.net:443" or "[2a03:2880::1]:443".
    public var endpoint: String {
        guard let host = remoteHost, !host.isEmpty else {
            return remotePort.map { "Unknown host, port \($0)" } ?? "Unknown host"
        }
        guard let remotePort else { return host }
        return host.contains(":") ? "[\(host)]:\(remotePort)" : "\(host):\(remotePort)"
    }

    mutating func close(with event: FlowEvent) {
        closedAt = event.timestamp
        bytesSent = event.bytesSent
        bytesReceived = event.bytesReceived
    }
}

extension NetworkConnection: TrafficEntry {
    public var timestamp: Date { startedAt }

    /// Byte counts arrive when the connection closes, so that's when they
    /// count toward upload and download speed.
    public var transferTimestamp: Date { closedAt ?? startedAt }

    public var measuredDurationSeconds: Double? { durationSeconds }

    public var isFailure: Bool { wasBlocked }
}

extension Sequence<NetworkConnection> {
    /// Filters connections by a case-insensitive substring match against the
    /// endpoint, transport and app, and/or by state and app. An empty query
    /// with `nil` filters matches everything.
    public func matching(
        query: String,
        state: ConnectionState? = nil,
        app: SourceApp? = nil
    ) -> [NetworkConnection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return filter { connection in
            if let state, connection.state != state {
                return false
            }
            if let app, connection.app.bundleIdentifier != app.bundleIdentifier {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return connection.endpoint.localizedCaseInsensitiveContains(trimmed)
                || connection.transport.label.localizedCaseInsensitiveContains(trimmed)
                || connection.app.displayName.localizedCaseInsensitiveContains(trimmed)
                || connection.app.bundleIdentifier.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Connections sorted newest first.
    public func sortedByRecency() -> [NetworkConnection] {
        sorted { $0.startedAt > $1.startedAt }
    }
}

/// A bounded log of connections built from flow events. A close updates the
/// connection its open created; once full, the oldest connections are dropped.
public struct ConnectionLog: Sendable {
    public let capacity: Int
    /// Connections in the order they were first seen, oldest first.
    public private(set) var connections: [NetworkConnection] = []
    private var indices: [UUID: Int] = [:]

    public init(capacity: Int = 3_000) {
        self.capacity = max(capacity, 0)
    }

    /// Adds new connections and closes existing ones, naming apps with `directory`.
    public mutating func apply(_ events: some Sequence<FlowEvent>, directory: AppDirectory) {
        for event in events {
            if let index = indices[event.flowID] {
                if event.kind == .closed {
                    connections[index].close(with: event)
                }
            } else {
                indices[event.flowID] = connections.count
                let app = directory.app(forSourceAppIdentifier: event.sourceAppIdentifier)
                connections.append(NetworkConnection(event: event, app: app))
            }
        }
        trimToCapacity()
    }

    /// Re-names every connection's app, e.g. after App Store lookups finish.
    public mutating func updateApps(using directory: AppDirectory) {
        var resolved: [String: SourceApp] = [:]
        for index in connections.indices {
            let identifier = connections[index].sourceAppIdentifier
            let key = identifier ?? ""
            let app = resolved[key] ?? directory.app(forSourceAppIdentifier: identifier)
            resolved[key] = app
            connections[index].app = app
        }
    }

    public mutating func removeAll() {
        connections.removeAll()
        indices.removeAll()
    }

    private mutating func trimToCapacity() {
        let overflow = connections.count - capacity
        guard overflow > 0 else { return }
        connections.removeFirst(overflow)
        indices = Dictionary(uniqueKeysWithValues: connections.enumerated().map { ($1.id, $0) })
    }
}
