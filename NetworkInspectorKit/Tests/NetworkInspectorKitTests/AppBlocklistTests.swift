import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("AppBlocklist")
struct AppBlocklistTests {
    @Test("an empty list blocks nothing")
    func emptyBlocksNothing() {
        let blocklist = AppBlocklist()
        #expect(blocklist.isEmpty)
        #expect(!blocklist.blocks(sourceAppIdentifier: "com.example.app"))
        #expect(!blocklist.blocks(sourceAppIdentifier: nil))
    }

    @Test(
        "matches the bundle identifier with or without a team prefix",
        arguments: [
            "com.example.courier",
            "A1B2C3D4E5.com.example.courier",
            "a1b2c3d4e5.com.example.courier",
            ".com.example.courier",
            "  COM.Example.Courier \n"
        ]
    )
    func matchesSourceAppIdentifierForms(source: String) {
        let blocklist = AppBlocklist(bundleIdentifiers: ["com.example.courier"])
        #expect(blocklist.blocks(sourceAppIdentifier: source))
    }

    @Test(
        "does not match other apps",
        arguments: [
            "com.example.frame",
            "A1B2C3D4E5.com.example.frame",
            "com.example.courier.widget",
            "com.example",
            "LONGERTEAMID1.com.example.courier",
            "example.courier",
            ""
        ]
    )
    func ignoresOtherApps(source: String) {
        let blocklist = AppBlocklist(bundleIdentifiers: ["com.example.courier"])
        #expect(!blocklist.blocks(sourceAppIdentifier: source))
    }

    @Test("setBlocked adds and removes apps case-insensitively")
    func setBlocked() {
        var blocklist = AppBlocklist()
        blocklist.setBlocked(true, bundleIdentifier: "Com.Example.Orbit")
        #expect(blocklist.contains("com.example.orbit"))
        #expect(blocklist.sortedBundleIdentifiers == ["com.example.orbit"])

        blocklist.setBlocked(false, bundleIdentifier: "COM.EXAMPLE.ORBIT")
        #expect(blocklist.isEmpty)
    }

    @Test("invalid bundle identifiers are ignored")
    func invalidIdentifiersIgnored() {
        var blocklist = AppBlocklist(bundleIdentifiers: ["", "nodots", "com..app", "com.ex ample", "unknown"])
        blocklist.setBlocked(true, bundleIdentifier: "bad id")
        #expect(blocklist.isEmpty)
    }

    @Test(
        "validates bundle identifiers",
        arguments: [
            ("com.example.app", true),
            ("com.apple.mobilesafari", true),
            ("com.my-company.app2", true),
            (" com.example.app ", true),
            ("com", false),
            ("com.", false),
            (".com.example", false),
            ("com.exa mple", false),
            ("com.example.app!", false),
            ("", false)
        ]
    )
    func validation(value: String, expected: Bool) {
        #expect(AppBlocklist.isValidBundleIdentifier(value) == expected)
    }

    @Test("round-trips through the filter vendor configuration")
    func vendorConfigurationRoundTrip() {
        let original = AppBlocklist(bundleIdentifiers: ["com.example.tempo", "com.example.ledger"])
        let restored = AppBlocklist(vendorConfiguration: original.vendorConfiguration)
        #expect(restored == original)
        #expect(original.vendorConfiguration[AppBlocklist.vendorConfigurationKey] as? [String]
            == ["com.example.ledger", "com.example.tempo"])
    }

    @Test("a missing or malformed vendor configuration blocks nothing")
    func malformedVendorConfiguration() {
        #expect(AppBlocklist(vendorConfiguration: nil).isEmpty)
        #expect(AppBlocklist(vendorConfiguration: [:]).isEmpty)
        #expect(AppBlocklist(vendorConfiguration: [AppBlocklist.vendorConfigurationKey: 42]).isEmpty)
    }

    @Test("round-trips through Codable")
    func codableRoundTrip() throws {
        let original = AppBlocklist(bundleIdentifiers: ["com.example.nimbus"])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(AppBlocklist.self, from: data) == original)
    }
}
