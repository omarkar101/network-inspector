import Foundation
import Network
@preconcurrency import NetworkExtension
import NetworkInspectorKit

/// The control half of the content filter that iOS requires alongside the data
/// provider. Blocking decisions are made locally from the vendor
/// configuration, so there are no remote rules to fetch here.
///
/// While traffic capture is on, the data provider marks every flow for
/// reporting and the system delivers those reports here, when a flow opens
/// and again when it closes. Unlike the data provider, this extension may
/// write to disk, so it appends each one to the flow journal in the app
/// group container, where the app reads it.
final class FilterControlProvider: NEFilterControlProvider {
    private let journal: FlowJournalWriter? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: FlowJournal.appGroupIdentifier)
        .map { FlowJournalWriter(directory: $0) }

    override func startFilter() async throws {}

    override func stopFilter(with reason: NEProviderStopReason) async {}

    override func handle(_ report: NEFilterReport) {
        guard let journal, let event = FlowEvent(report: report) else { return }
        journal.append(event)
    }
}

private extension FlowEvent {
    /// The journal entry for a report, or nil for reports that aren't a
    /// flow opening or closing.
    init?(report: NEFilterReport) {
        guard let flow = report.flow else { return nil }

        let kind: Kind
        switch report.event {
        case .newFlow: kind = .opened
        case .flowClosed: kind = .closed
        default: return nil
        }

        var host: String?
        var port: Int?
        var transport = Transport.other
        if let socketFlow = flow as? NEFilterSocketFlow {
            // Set when the app connected by name (URLSession, Network.framework).
            host = socketFlow.remoteHostname
            if case let .hostPort(endpointHost, endpointPort)? = socketFlow.remoteFlowEndpoint {
                host = host ?? Self.describe(endpointHost)
                port = Int(endpointPort.rawValue)
            }
            switch socketFlow.socketProtocol {
            case IPPROTO_TCP: transport = .tcp
            case IPPROTO_UDP: transport = .udp
            default: transport = .other
            }
        }

        self.init(
            flowID: flow.identifier,
            kind: kind,
            timestamp: .now,
            sourceAppIdentifier: flow.sourceAppIdentifier,
            remoteHost: host ?? flow.url?.host(),
            remotePort: port,
            transport: transport,
            isInbound: flow.direction == .inbound,
            wasBlocked: report.action == .drop,
            // Only non-zero in the report for a closed flow.
            bytesReceived: report.bytesInboundCount,
            bytesSent: report.bytesOutboundCount
        )
    }

    // Qualified: NetworkExtension has an older `NWEndpoint` class too.
    private static func describe(_ host: Network.NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _): name
        case .ipv4(let address): "\(address)"
        case .ipv6(let address): "\(address)"
        @unknown default: "\(host)"
        }
    }
}
