import Foundation

/// A connection opening or closing, as the content filter reports it.
///
/// The filter control provider appends these to the `FlowJournal`; the app
/// reads them back and assembles them into `NetworkConnection`s.
public struct FlowEvent: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        case opened
        case closed
    }

    public enum Transport: String, Sendable, Codable, CaseIterable {
        case tcp
        case udp
        case other

        /// A short badge label, e.g. "TCP".
        public var label: String {
            switch self {
            case .tcp: "TCP"
            case .udp: "UDP"
            case .other: "Other"
            }
        }
    }

    /// Identifies the connection, so its close can be matched to its open.
    public let flowID: UUID
    public let kind: Kind
    public let timestamp: Date
    /// The source app's signing identifier (`NEFilterFlow.sourceAppIdentifier`),
    /// e.g. `A1B2C3D4E5.net.whatsapp.WhatsApp`.
    public let sourceAppIdentifier: String?
    /// The hostname the app connected to, or the IP address when it
    /// connected by address.
    public let remoteHost: String?
    public let remotePort: Int?
    public let transport: Transport
    public let isInbound: Bool
    /// Whether the filter dropped the connection because its app is blocked.
    public let wasBlocked: Bool
    /// Bytes received over the connection. Only known once it closes.
    public let bytesReceived: Int
    /// Bytes sent over the connection. Only known once it closes.
    public let bytesSent: Int

    public init(
        flowID: UUID,
        kind: Kind,
        timestamp: Date,
        sourceAppIdentifier: String?,
        remoteHost: String? = nil,
        remotePort: Int? = nil,
        transport: Transport = .tcp,
        isInbound: Bool = false,
        wasBlocked: Bool = false,
        bytesReceived: Int = 0,
        bytesSent: Int = 0
    ) {
        self.flowID = flowID
        self.kind = kind
        self.timestamp = timestamp
        self.sourceAppIdentifier = sourceAppIdentifier
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.transport = transport
        self.isInbound = isInbound
        self.wasBlocked = wasBlocked
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
    }
}
