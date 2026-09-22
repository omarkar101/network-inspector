@preconcurrency import NetworkExtension
import NetworkInspectorKit

/// Sees every new socket flow on the device and drops the ones that come from
/// an app on the blocklist, which cuts that app off from the internet.
///
/// The blocklist arrives through the filter's vendor configuration, which the
/// system keeps up to date whenever the app saves a new one. The provider runs
/// in a strict sandbox (no disk writes, no network), so it only reads it.
final class FilterDataProvider: NEFilterDataProvider {
    override func startFilter() async throws {}

    override func stopFilter(with reason: NEProviderStopReason) async {}

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let blocklist = AppBlocklist(vendorConfiguration: filterConfiguration.vendorConfiguration)
        return blocklist.blocks(sourceAppIdentifier: flow.sourceAppIdentifier) ? .drop() : .allow()
    }
}
