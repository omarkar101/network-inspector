/// The app on the device that issued a captured request.
public struct SourceApp: Sendable, Hashable, Identifiable {
    public let bundleIdentifier: String
    public let displayName: String
    /// An SF Symbol name used as the app's glyph in lists.
    public let symbolName: String

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, displayName: String, symbolName: String = "app.fill") {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.symbolName = symbolName
    }

    /// Placeholder for traffic that could not be attributed to an app.
    public static let unknown = SourceApp(
        bundleIdentifier: "unknown",
        displayName: "Unknown",
        symbolName: "questionmark.app.dashed"
    )

    /// A stable hue in `0..<1` derived from the bundle identifier, so each app
    /// keeps the same accent color across launches (FNV-1a hash).
    public var tintHue: Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in bundleIdentifier.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return Double(hash % 360) / 360
    }
}
