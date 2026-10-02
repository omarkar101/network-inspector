import Foundation

/// The file that carries captured connections from the content filter to the
/// app: one JSON-encoded `FlowEvent` per line, in the app group container
/// both of them can reach.
///
/// The filter's data provider sees every connection but its sandbox can't
/// write anywhere, so it asks for a report on each one; the control
/// provider receives those reports and writes them here with a
/// `FlowJournalWriter`. The app follows the file with a `FlowJournalReader`.
///
/// Once the file reaches `maxFileSize` the writer moves it to
/// `rotatedFileName` and starts a new one, so the journal keeps recent
/// history and never grows past twice that size.
public enum FlowJournal {
    /// App group shared by the app and the filter control provider.
    public static let appGroupIdentifier = "group.com.omarkar.networkinspector"
    public static let fileName = "flows.jsonl"
    public static let rotatedFileName = "flows.1.jsonl"
    public static let maxFileSize = 2 * 1024 * 1024

    private static let newline = UInt8(ascii: "\n")

    /// One journal line: the event as JSON, followed by a newline.
    public static func line(for event: FlowEvent) throws -> Data {
        var data = try JSONEncoder().encode(event)
        data.append(newline)
        return data
    }

    /// Decodes the complete lines in `data`, skipping any that aren't valid
    /// events. `consumed` counts the bytes through the last newline; a
    /// trailing partial line is left for the next read.
    public static func events(in data: Data) -> (events: [FlowEvent], consumed: Int) {
        guard let lastNewline = data.lastIndex(of: newline) else { return ([], 0) }
        let complete = data[data.startIndex...lastNewline]
        let decoder = JSONDecoder()
        let events = complete
            .split(separator: newline)
            .compactMap { try? decoder.decode(FlowEvent.self, from: Data($0)) }
        return (events, complete.count)
    }
}

/// Appends events to the journal in `directory`, rotating the file when it
/// gets too big. Safe to call from any thread.
public final class FlowJournalWriter: @unchecked Sendable {
    public let directory: URL
    public let maxFileSize: Int

    private let lock = NSLock()
    private var handle: FileHandle?

    public init(directory: URL, maxFileSize: Int = FlowJournal.maxFileSize) {
        self.directory = directory
        self.maxFileSize = maxFileSize
    }

    deinit {
        try? handle?.close()
    }

    /// Appends one event. Failures are dropped: losing a journal entry is
    /// better than holding up the filter.
    public func append(_ event: FlowEvent) {
        guard let line = try? FlowJournal.line(for: event) else { return }
        lock.lock()
        defer { lock.unlock() }

        do {
            let handle = try openHandle()
            try handle.write(contentsOf: line)
            if try handle.offset() >= UInt64(maxFileSize) {
                try rotate()
            }
        } catch {
            try? handle?.close()
            handle = nil
        }
    }

    private func openHandle() throws -> FileHandle {
        if let handle { return handle }
        let url = directory.appendingPathComponent(FlowJournal.fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        _ = try handle.seekToEnd()
        self.handle = handle
        return handle
    }

    private func rotate() throws {
        try handle?.close()
        handle = nil
        let current = directory.appendingPathComponent(FlowJournal.fileName)
        let rotated = directory.appendingPathComponent(FlowJournal.rotatedFileName)
        if FileManager.default.fileExists(atPath: rotated.path) {
            try FileManager.default.removeItem(at: rotated)
        }
        try FileManager.default.moveItem(at: current, to: rotated)
    }
}

/// Reads the events appended to the journal in `directory` since the last
/// read, following the writer across file rotations.
public struct FlowJournalReader: Sendable {
    /// A spot in one particular file, identified by its file system number
    /// so a rotation (which renames the file) can be told apart from growth.
    private struct Position: Sendable, Equatable {
        var file: UInt64
        var offset: UInt64
    }

    public let directory: URL
    private var position: Position?

    public init(directory: URL) {
        self.directory = directory
    }

    /// Events written since the last call, oldest first. The first call
    /// returns the whole journal, so traffic captured while the app wasn't
    /// running shows up too.
    public mutating func readNewEvents() -> [FlowEvent] {
        let currentURL = directory.appendingPathComponent(FlowJournal.fileName)
        let rotatedURL = directory.appendingPathComponent(FlowJournal.rotatedFileName)
        let current = Self.fileNumber(of: currentURL)
        let rotated = Self.fileNumber(of: rotatedURL)
        var events: [FlowEvent] = []

        // The file being read is gone (rotated out twice): start over from
        // the oldest data that's left.
        if let file = position?.file, file != current, file != rotated {
            position = nil
        }

        // On the first read, start with the rotated history. If the file
        // being read has been rotated since, finish what's left of it.
        if let rotated, rotated != current, position == nil || position?.file == rotated {
            let chunk = Self.read(rotatedURL, from: position?.offset ?? 0)
            events += chunk.events
            position = Position(file: rotated, offset: chunk.end)
        }

        guard let current else { return events }
        let start = position?.file == current ? position?.offset ?? 0 : 0
        let chunk = Self.read(currentURL, from: start)
        events += chunk.events
        position = Position(file: current, offset: chunk.end)
        return events
    }

    /// Decodes the complete lines from `offset` on. `end` is where the next
    /// read should start; reading restarts at 0 if the file shrank.
    private static func read(_ url: URL, from offset: UInt64) -> (events: [FlowEvent], end: UInt64) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return ([], offset) }
        defer { try? handle.close() }

        do {
            let size = try handle.seekToEnd()
            let start = offset <= size ? offset : 0
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return ([], start) }
            let decoded = FlowJournal.events(in: data)
            return (decoded.events, start + UInt64(decoded.consumed))
        } catch {
            return ([], offset)
        }
    }

    private static func fileNumber(of url: URL) -> UInt64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        switch attributes[.systemFileNumber] {
        case let number as NSNumber: return number.uint64Value
        case let number as UInt64: return number
        case let number as UInt: return UInt64(number)
        case let number as Int: return UInt64(exactly: number)
        default: return nil
        }
    }
}
