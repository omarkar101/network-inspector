/// What the content filter should do, as sent to it through the filter's
/// vendor configuration: which apps to cut off, and whether to report every
/// connection so the app can list real traffic by app.
public struct FilterSettings: Sendable, Hashable {
    /// Key under which the capture flag is stored in `NEFilterProviderConfiguration.vendorConfiguration`.
    public static let capturesTrafficKey = "capturesTraffic"

    public var blocklist: AppBlocklist
    public var capturesTraffic: Bool

    public init(blocklist: AppBlocklist = AppBlocklist(), capturesTraffic: Bool = false) {
        self.blocklist = blocklist
        self.capturesTraffic = capturesTraffic
    }

    /// Reads the settings back out of a filter vendor configuration. Anything
    /// missing or malformed falls back to doing nothing: no app is blocked
    /// and no traffic is captured.
    public init(vendorConfiguration: [String: Any]?) {
        blocklist = AppBlocklist(vendorConfiguration: vendorConfiguration)
        capturesTraffic = (vendorConfiguration?[Self.capturesTrafficKey] as? Bool) ?? false
    }

    /// The settings encoded for `NEFilterProviderConfiguration.vendorConfiguration`.
    public var vendorConfiguration: [String: Any] {
        var configuration = blocklist.vendorConfiguration
        configuration[Self.capturesTrafficKey] = capturesTraffic
        return configuration
    }

    /// Whether the filter has anything to do, i.e. should be running at all.
    public var needsFilter: Bool {
        capturesTraffic || !blocklist.isEmpty
    }
}
