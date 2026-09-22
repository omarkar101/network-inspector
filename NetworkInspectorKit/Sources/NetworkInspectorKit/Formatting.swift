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

    /// Formats a fraction in `0...1` as a percentage, e.g. "12%".
    ///
    /// Non-zero values that would round to 0 are shown as "<1%" so a rare
    /// error never reads as none at all.
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite, fraction >= 0 else { return "—" }
        let percent = (fraction * 100).rounded()
        if percent == 0, fraction > 0 {
            return "<1%"
        }
        return "\(Int(percent))%"
    }

    /// Formats a per-minute rate, e.g. "2.5/min" below 10 and "42/min" above.
    public static func rate(perMinute value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        if value < 10 {
            let tenths = (value * 10).rounded() / 10
            if tenths == tenths.rounded() {
                return "\(Int(tenths))/min"
            }
            return String(format: "%.1f/min", tenths)
        }
        return "\(Int(value.rounded()))/min"
    }
}
