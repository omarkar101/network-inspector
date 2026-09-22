import Foundation

/// The apps whose internet access is cut off by the content filter.
///
/// The app edits this list; the filter data provider extension receives it
/// through the filter's vendor configuration and drops every network flow
/// whose source app is on it. Bundle identifiers are compared
/// case-insensitively, so they are stored lowercased.
public struct AppBlocklist: Sendable, Hashable, Codable {
    /// Key under which the list is stored in `NEFilterProviderConfiguration.vendorConfiguration`.
    public static let vendorConfigurationKey = "blockedBundleIdentifiers"

    public private(set) var bundleIdentifiers: Set<String>

    public init() {
        bundleIdentifiers = []
    }

    public init(bundleIdentifiers: some Sequence<String>) {
        self.bundleIdentifiers = Set(bundleIdentifiers.compactMap(Self.normalized))
    }

    /// Reads the list back out of a filter vendor configuration. A missing or
    /// malformed configuration yields an empty list, so nothing is blocked.
    public init(vendorConfiguration: [String: Any]?) {
        let identifiers = vendorConfiguration?[Self.vendorConfigurationKey] as? [String] ?? []
        self.init(bundleIdentifiers: identifiers)
    }

    /// The list encoded for `NEFilterProviderConfiguration.vendorConfiguration`.
    public var vendorConfiguration: [String: Any] {
        [Self.vendorConfigurationKey: sortedBundleIdentifiers]
    }

    public var isEmpty: Bool { bundleIdentifiers.isEmpty }

    public var sortedBundleIdentifiers: [String] { bundleIdentifiers.sorted() }

    public func contains(_ bundleIdentifier: String) -> Bool {
        guard let normalized = Self.normalized(bundleIdentifier) else { return false }
        return bundleIdentifiers.contains(normalized)
    }

    /// Adds or removes an app. Invalid bundle identifiers are ignored.
    public mutating func setBlocked(_ blocked: Bool, bundleIdentifier: String) {
        guard let normalized = Self.normalized(bundleIdentifier) else { return }
        if blocked {
            bundleIdentifiers.insert(normalized)
        } else {
            bundleIdentifiers.remove(normalized)
        }
    }

    /// Whether a network flow from the given source app should be dropped.
    ///
    /// `NEFilterFlow.sourceAppIdentifier` is the app's signing identifier,
    /// which is usually the bundle identifier prefixed by the team ID
    /// (`A1B2C3D4E5.com.example.app`) or by an empty team for Apple's own
    /// apps (`.com.apple.mobilesafari`). Both forms, and a bare bundle
    /// identifier, match.
    public func blocks(sourceAppIdentifier: String?) -> Bool {
        guard !bundleIdentifiers.isEmpty,
              let raw = sourceAppIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty
        else { return false }

        if bundleIdentifiers.contains(raw) {
            return true
        }
        if let stripped = Self.strippingTeamPrefix(raw) {
            return bundleIdentifiers.contains(stripped)
        }
        return false
    }

    /// Whether `value` looks like a bundle identifier: at least two
    /// dot-separated components of ASCII letters, digits and hyphens.
    public static func isValidBundleIdentifier(_ value: String) -> Bool {
        normalized(value) != nil
    }

    static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(isBundleIdentifierCharacter) })
        else { return nil }
        return trimmed
    }

    /// Drops a leading team ID (10 letters/digits) or empty team, if present.
    static func strippingTeamPrefix(_ identifier: String) -> String? {
        guard let dot = identifier.firstIndex(of: ".") else { return nil }
        let prefix = identifier[..<dot]
        guard prefix.isEmpty || (prefix.count == 10 && prefix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
        else { return nil }
        let rest = identifier[identifier.index(after: dot)...]
        return rest.isEmpty ? nil : String(rest)
    }

    private static func isBundleIdentifierCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || character == "-")
    }
}
