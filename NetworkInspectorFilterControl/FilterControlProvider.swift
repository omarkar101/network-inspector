@preconcurrency import NetworkExtension

/// The control half of the content filter that iOS requires alongside the data
/// provider. Blocking decisions are made locally from the vendor
/// configuration, so there are no remote rules to fetch here.
final class FilterControlProvider: NEFilterControlProvider {
    override func startFilter() async throws {}

    override func stopFilter(with reason: NEProviderStopReason) async {}
}
