import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("FilterSettings")
struct FilterSettingsTests {
    @Test("round-trips through the filter vendor configuration")
    func vendorConfigurationRoundTrip() {
        let original = FilterSettings(
            blocklist: AppBlocklist(bundleIdentifiers: ["net.whatsapp.whatsapp"]),
            capturesTraffic: true
        )
        let restored = FilterSettings(vendorConfiguration: original.vendorConfiguration)
        #expect(restored == original)
    }

    @Test("the blocklist stays readable on its own")
    func blocklistCompatible() {
        let settings = FilterSettings(
            blocklist: AppBlocklist(bundleIdentifiers: ["com.example.tempo"]),
            capturesTraffic: true
        )
        #expect(AppBlocklist(vendorConfiguration: settings.vendorConfiguration) == settings.blocklist)
    }

    @Test("a missing or malformed vendor configuration does nothing")
    func malformedVendorConfiguration() {
        for configuration in [nil, [:], [FilterSettings.capturesTrafficKey: "yes"]] as [[String: Any]?] {
            let settings = FilterSettings(vendorConfiguration: configuration)
            #expect(!settings.capturesTraffic)
            #expect(settings.blocklist.isEmpty)
            #expect(!settings.needsFilter)
        }
    }

    @Test("the filter is needed to capture traffic or to block an app")
    func needsFilter() {
        let blocklist = AppBlocklist(bundleIdentifiers: ["com.example.ledger"])
        #expect(!FilterSettings().needsFilter)
        #expect(FilterSettings(capturesTraffic: true).needsFilter)
        #expect(FilterSettings(blocklist: blocklist).needsFilter)
        #expect(FilterSettings(blocklist: blocklist, capturesTraffic: true).needsFilter)
    }
}
