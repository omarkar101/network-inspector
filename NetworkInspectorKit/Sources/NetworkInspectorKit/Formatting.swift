import Foundation

/// Pure formatting helpers used when rendering captured request/response entries.
public enum Formatting {
    /// Formats a duration in seconds as a short, human-readable string.
    ///
    /// - `< 1s` is shown in milliseconds, e.g. "234 ms".
    /// - `>= 1s` is shown with a single fractional digit, e.g. "1.2 s".
    public static func duration(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }

        if seconds < 1 {
            let ms = (seconds * 1000).rounded()
            return "\(Int(ms)) ms"
        }

        let tenths = (seconds * 10).rounded() / 10
        if tenths == tenths.rounded() {
            return "\(Int(tenths)) s"
        }
        return String(format: "%.1f s", tenths)
    }

    /// Formats a byte count using binary (1024-based) units, e.g. "1.5 KB".
    ///
    /// Uses the same abbreviations as `ByteCountFormatter` would, but is a pure
    /// function so it can be unit tested without relying on Foundation's
    /// locale-dependent formatter on non-Apple platforms.
    public static func byteSize(_ bytes: Int) -> String {
        guard bytes >= 0 else { return "—" }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) \(units[unitIndex])"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", rounded, units[unitIndex])
    }
}
