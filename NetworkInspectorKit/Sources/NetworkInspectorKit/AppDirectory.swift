import Foundation

/// An app's name and icon from the App Store.
public struct AppStoreListing: Sendable, Hashable, Codable {
    public let bundleIdentifier: String
    public let name: String
    public let iconURL: URL?

    public init(bundleIdentifier: String, name: String, iconURL: URL?) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.iconURL = iconURL
    }
}

/// Turns the source app identifiers that the content filter reports (such
/// as `A1B2C3D4E5.net.whatsapp.WhatsApp`) into named apps.
///
/// Names come from `KnownApps` first, then from App Store listings the app
/// has looked up, and otherwise are made up from the bundle identifier.
/// App extensions are named after the app that contains them.
public struct AppDirectory: Sendable {
    /// App Store listings, keyed by lowercased bundle identifier.
    public private(set) var listings: [String: AppStoreListing] = [:]

    public init(listings: [AppStoreListing] = []) {
        for listing in listings {
            add(listing)
        }
    }

    public mutating func add(_ listing: AppStoreListing) {
        listings[listing.bundleIdentifier.lowercased()] = listing
    }

    /// The app behind a source app identifier. Unattributed traffic maps to
    /// `SourceApp.unknown`.
    public func app(forSourceAppIdentifier identifier: String?) -> SourceApp {
        guard let bundleIdentifier = Self.bundleIdentifier(fromSourceAppIdentifier: identifier) else {
            return .unknown
        }
        if let app = namedApp(bundleIdentifier) {
            return app
        }
        // Extensions (widgets, share sheets, notification services) run as
        // their own processes, e.g. `net.whatsapp.WhatsApp.ServiceExtension`.
        for parent in Self.ancestors(of: bundleIdentifier) {
            if let app = namedApp(parent) {
                let extensionName = bundleIdentifier.dropFirst(parent.count + 1)
                return SourceApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: "\(app.displayName) (\(extensionName))",
                    symbolName: app.symbolName,
                    iconURL: app.iconURL
                )
            }
        }
        return SourceApp(
            bundleIdentifier: bundleIdentifier,
            displayName: Self.fallbackName(for: bundleIdentifier),
            symbolName: Self.isApple(bundleIdentifier) ? "apple.logo" : "app.fill"
        )
    }

    /// The app with this exact bundle identifier, if it's known or listed.
    /// Known apps keep their short built-in name but take the listed icon.
    private func namedApp(_ bundleIdentifier: String) -> SourceApp? {
        let known = KnownApps.app(bundleIdentifier: bundleIdentifier)
        let listing = listings[bundleIdentifier.lowercased()]
        guard let name = known?.displayName ?? listing?.name else { return nil }
        return SourceApp(
            bundleIdentifier: bundleIdentifier,
            displayName: name,
            symbolName: known?.symbolName ?? "app.fill",
            iconURL: listing?.iconURL
        )
    }

    /// The bundle identifier in a source app identifier, without its team ID
    /// prefix: `A1B2C3D4E5.net.whatsapp.WhatsApp` → `net.whatsapp.WhatsApp`.
    /// Apple's own apps have an empty prefix (`.com.apple.mobilesafari`).
    public static func bundleIdentifier(fromSourceAppIdentifier identifier: String?) -> String? {
        guard let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return AppBlocklist.strippingTeamPrefix(trimmed) ?? trimmed
    }

    /// Bundle identifiers worth an App Store lookup for this source app: the
    /// app itself, then the apps that might contain it as an extension.
    /// Apple's built-in apps and services aren't on the App Store, so they
    /// get none and are named from `KnownApps` instead.
    public static func lookupCandidates(forSourceAppIdentifier identifier: String?) -> [String] {
        guard let bundleIdentifier = bundleIdentifier(fromSourceAppIdentifier: identifier),
              !isApple(bundleIdentifier)
        else { return [] }
        let parents = ancestors(of: bundleIdentifier).filter { $0.split(separator: ".").count >= 3 }
        return [bundleIdentifier] + parents
    }

    /// Parent identifiers, nearest first, down to two components:
    /// `a.b.c.d` → `a.b.c`, `a.b`.
    static func ancestors(of bundleIdentifier: String) -> [String] {
        var components = bundleIdentifier.split(separator: ".", omittingEmptySubsequences: false)
        var parents: [String] = []
        while components.count > 2 {
            components.removeLast()
            parents.append(components.joined(separator: "."))
        }
        return parents
    }

    /// A readable name made from the bundle identifier itself: its last
    /// meaningful component, capitalized (`com.example.coolgame.ios` → `Coolgame`).
    static func fallbackName(for bundleIdentifier: String) -> String {
        let generic: Set<String> = ["app", "client", "ios", "iphone", "ipad", "mobile"]
        let components = bundleIdentifier.split(separator: ".").map(String.init)
        let name = components.last(where: { !generic.contains($0.lowercased()) })
            ?? components.last
            ?? bundleIdentifier
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func isApple(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier.lowercased().hasPrefix("com.apple.")
    }
}

/// Builds and parses App Store lookups (the iTunes Lookup API), which give
/// an app's name and icon for its bundle identifier.
public enum AppStoreLookup {
    /// The lookup URL for one app, in the given App Store country (e.g. "US").
    public static func url(bundleIdentifier: String, country: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        var queryItems = [URLQueryItem(name: "bundleId", value: bundleIdentifier)]
        if let country, !country.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: country.lowercased()))
        }
        components.queryItems = queryItems
        return components.url
    }

    /// The listing for `bundleIdentifier` in a lookup response, or nil when
    /// the App Store doesn't have that app. Throws when `data` isn't a
    /// lookup response at all.
    public static func listing(from data: Data, bundleIdentifier: String) throws -> AppStoreListing? {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let wanted = bundleIdentifier.lowercased()
        guard let result = response.results.first(where: { $0.bundleId?.lowercased() == wanted }),
              let trackName = result.trackName
        else { return nil }

        let name = shortName(trackName)
        guard !name.isEmpty else { return nil }
        let icon = (result.artworkUrl100 ?? result.artworkUrl60 ?? result.artworkUrl512)
            .flatMap { URL(string: $0) }
        return AppStoreListing(bundleIdentifier: bundleIdentifier, name: name, iconURL: icon)
    }

    /// Drops the tagline many App Store names carry:
    /// "Spotify: Music and Podcasts" → "Spotify", "Uber - Request a ride" → "Uber".
    static func shortName(_ name: String) -> String {
        let full = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var short = full
        for separator in [": ", " - ", " – ", " — ", " | "] {
            if let range = short.range(of: separator) {
                short = String(short[..<range.lowerBound])
            }
        }
        short = short.trimmingCharacters(in: .whitespacesAndNewlines)
        return short.isEmpty ? full : short
    }

    private struct Response: Decodable {
        let results: [Listing]
    }

    private struct Listing: Decodable {
        let bundleId: String?
        let trackName: String?
        let artworkUrl60: String?
        let artworkUrl100: String?
        let artworkUrl512: String?
    }
}
