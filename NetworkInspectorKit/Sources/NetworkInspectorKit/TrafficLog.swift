/// A bounded, chronological buffer of captured requests. Once full, appending
/// evicts the oldest entries so a long-running live capture stays cheap.
public struct TrafficLog: Sendable {
    public let capacity: Int
    /// Entries in insertion order, oldest first.
    public private(set) var entries: [CapturedRequest] = []

    public init(capacity: Int = 2_000, entries: [CapturedRequest] = []) {
        self.capacity = max(capacity, 0)
        append(contentsOf: entries)
    }

    public mutating func append(_ entry: CapturedRequest) {
        append(contentsOf: [entry])
    }

    public mutating func append(contentsOf newEntries: [CapturedRequest]) {
        entries.append(contentsOf: newEntries)
        let overflow = entries.count - capacity
        if overflow > 0 {
            entries.removeFirst(overflow)
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }
}
