@preconcurrency import NetworkExtension
import NetworkInspectorKit

/// Sees every new socket flow on the device. Drops the ones that come from
/// an app on the blocklist, which cuts that app off from the internet, and,
/// while traffic capture is on, asks the system to report every flow to the
/// control provider, which records it for the app's traffic list.
///
/// The settings arrive through the filter's vendor configuration, which the
/// system keeps up to date whenever the app saves a new one. The provider runs
/// in a strict sandbox (no disk writes, no network, no IPC), so it can't hand
/// flows to the app itself; reports are the supported way out.
final class FilterDataProvider: NEFilterDataProvider {
    override func startFilter() async throws {}

    override func stopFilter(with reason: NEProviderStopReason) async {}

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let settings = FilterSettings(vendorConfiguration: filterConfiguration.vendorConfiguration)
        let verdict: NEFilterNewFlowVerdict = settings.blocklist.blocks(sourceAppIdentifier: flow.sourceAppIdentifier)
            ? .drop()
            : .allow()
        // Reports the flow now and again when it closes (with byte counts),
        // without waiting on the control provider.
        verdict.shouldReport = settings.capturesTraffic
        return verdict
    }
}
