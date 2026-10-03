import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("AppDirectory")
struct AppDirectoryTests {
    private let icon = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/100x100bb.jpg")

    @Test(
        "strips the team ID prefix from source app identifiers",
        arguments: [
            ("57T9237FN3.net.whatsapp.WhatsApp", "net.whatsapp.WhatsApp"),
            (".com.apple.mobilesafari", "com.apple.mobilesafari"),
            ("com.example.app", "com.example.app"),
            ("  A1B2C3D4E5.pinterest \n", "pinterest")
        ]
    )
    func bundleIdentifier(source: String, expected: String) {
        #expect(AppDirectory.bundleIdentifier(fromSourceAppIdentifier: source) == expected)
    }

    @Test("names well-known apps and system services")
    func knownApps() {
        let directory = AppDirectory()
        let whatsApp = directory.app(forSourceAppIdentifier: "57T9237FN3.net.whatsapp.WhatsApp")
        #expect(whatsApp.displayName == "WhatsApp")
        #expect(whatsApp.bundleIdentifier == "net.whatsapp.WhatsApp")
        #expect(whatsApp.iconURL == nil)

        #expect(directory.app(forSourceAppIdentifier: ".com.apple.mobilesafari").displayName == "Safari")
        #expect(directory.app(forSourceAppIdentifier: "com.apple.nsurlsessiond").displayName == "Background Transfers")
    }

    @Test("unattributed traffic is unknown")
    func unknownSource() {
        #expect(AppDirectory().app(forSourceAppIdentifier: nil) == .unknown)
        #expect(AppDirectory().app(forSourceAppIdentifier: "  ") == .unknown)
    }

    @Test("App Store listings name other apps and give every app its icon")
    func listings() {
        let directory = AppDirectory(listings: [
            AppStoreListing(bundleIdentifier: "com.example.Weather", name: "Weather Pro", iconURL: icon),
            AppStoreListing(bundleIdentifier: "net.whatsapp.WhatsApp", name: "WhatsApp Messenger", iconURL: icon)
        ])

        let weather = directory.app(forSourceAppIdentifier: "A1B2C3D4E5.com.example.weather")
        #expect(weather.displayName == "Weather Pro")
        #expect(weather.iconURL == icon)

        // The short built-in name wins, but the icon comes from the listing.
        let whatsApp = directory.app(forSourceAppIdentifier: "57T9237FN3.net.whatsapp.WhatsApp")
        #expect(whatsApp.displayName == "WhatsApp")
        #expect(whatsApp.iconURL == icon)
    }

    @Test("extensions are named after the app that contains them")
    func extensions() {
        let directory = AppDirectory(listings: [
            AppStoreListing(bundleIdentifier: "com.example.weather", name: "Weather Pro", iconURL: icon)
        ])

        let service = directory.app(forSourceAppIdentifier: "57T9237FN3.net.whatsapp.WhatsApp.ServiceExtension")
        #expect(service.displayName == "WhatsApp (ServiceExtension)")
        #expect(service.bundleIdentifier == "net.whatsapp.WhatsApp.ServiceExtension")

        let widget = directory.app(forSourceAppIdentifier: "A1B2C3D4E5.com.example.weather.widgets.today")
        #expect(widget.displayName == "Weather Pro (widgets.today)")
        #expect(widget.iconURL == icon)
    }

    @Test(
        "unknown apps get a name made from their bundle identifier",
        arguments: [
            ("com.example.weatherapp", "Weatherapp"),
            ("com.example.coolgame.ios", "Coolgame"),
            ("com.example.app", "Example"),
            ("io.foo.Bar", "Bar")
        ]
    )
    func fallbackNames(bundleIdentifier: String, expected: String) {
        let app = AppDirectory().app(forSourceAppIdentifier: "A1B2C3D4E5.\(bundleIdentifier)")
        #expect(app.displayName == expected)
        #expect(app.symbolName == "app.fill")
    }

    @Test("unknown Apple services get the Apple glyph")
    func unknownAppleService() {
        let app = AppDirectory().app(forSourceAppIdentifier: ".com.apple.somethingd")
        #expect(app.displayName == "Somethingd")
        #expect(app.symbolName == "apple.logo")
    }

    @Test("looks up the app and the apps that could contain it, but not Apple's")
    func lookupCandidates() {
        #expect(AppDirectory.lookupCandidates(forSourceAppIdentifier: "A1B2C3D4E5.com.example.app.widget")
            == ["com.example.app.widget", "com.example.app"])
        #expect(AppDirectory.lookupCandidates(forSourceAppIdentifier: "57T9237FN3.net.whatsapp.WhatsApp")
            == ["net.whatsapp.WhatsApp"])
        #expect(AppDirectory.lookupCandidates(forSourceAppIdentifier: ".com.apple.mobilesafari").isEmpty)
        #expect(AppDirectory.lookupCandidates(forSourceAppIdentifier: nil).isEmpty)
    }

    // MARK: App Store lookup

    @Test("builds the lookup URL")
    func lookupURL() throws {
        let url = try #require(AppStoreLookup.url(bundleIdentifier: "net.whatsapp.WhatsApp", country: "DE"))
        #expect(url.absoluteString == "https://itunes.apple.com/lookup?bundleId=net.whatsapp.WhatsApp&country=de")
        #expect(AppStoreLookup.url(bundleIdentifier: "com.example.app")?.absoluteString
            == "https://itunes.apple.com/lookup?bundleId=com.example.app")
    }

    @Test("parses a lookup response")
    func parseListing() throws {
        let json = """
        {"resultCount":1,"results":[{"kind":"software","bundleId":"com.spotify.client",
        "trackName":"Spotify: Music and Podcasts","artworkUrl60":"https://example.com/60.jpg",
        "artworkUrl100":"https://example.com/100.jpg"}]}
        """
        let listing = try #require(try AppStoreLookup.listing(from: Data(json.utf8), bundleIdentifier: "com.spotify.client"))
        #expect(listing.name == "Spotify")
        #expect(listing.iconURL == URL(string: "https://example.com/100.jpg"))
        #expect(listing.bundleIdentifier == "com.spotify.client")
    }

    @Test("an app the App Store doesn't have has no listing")
    func noListing() throws {
        let empty = Data(#"{"resultCount":0,"results":[]}"#.utf8)
        #expect(try AppStoreLookup.listing(from: empty, bundleIdentifier: "com.example.app") == nil)

        let other = Data(#"{"resultCount":1,"results":[{"bundleId":"com.other.app","trackName":"Other"}]}"#.utf8)
        #expect(try AppStoreLookup.listing(from: other, bundleIdentifier: "com.example.app") == nil)

        #expect(throws: (any Error).self) {
            try AppStoreLookup.listing(from: Data("<html>".utf8), bundleIdentifier: "com.example.app")
        }
    }

    @Test(
        "drops taglines from App Store names",
        arguments: [
            ("Spotify: Music and Podcasts", "Spotify"),
            ("Uber - Request a ride", "Uber"),
            ("YouTube – Watch, Listen, Stream", "YouTube"),
            ("WhatsApp Messenger", "WhatsApp Messenger"),
            ("Re:Mind", "Re:Mind"),
            (": Odd", ": Odd")
        ]
    )
    func shortNames(name: String, expected: String) {
        #expect(AppStoreLookup.shortName(name) == expected)
    }
}
