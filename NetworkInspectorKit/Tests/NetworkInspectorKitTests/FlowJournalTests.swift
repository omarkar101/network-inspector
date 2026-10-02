import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("FlowJournal")
struct FlowJournalTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ kind: FlowEvent.Kind = .opened, host: String = "g.whatsapp.net") -> FlowEvent {
        FlowEvent(
            flowID: UUID(),
            kind: kind,
            timestamp: start,
            sourceAppIdentifier: "A1B2C3D4E5.net.whatsapp.WhatsApp",
            remoteHost: host,
            remotePort: 443,
            transport: .tcp,
            bytesReceived: kind == .closed ? 2_048 : 0,
            bytesSent: kind == .closed ? 512 : 0
        )
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowJournalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    // MARK: Lines

    @Test("events round-trip through journal lines")
    func lineRoundTrip() throws {
        let events = [event(.opened), event(.closed, host: "2a03:2880::1")]
        let data = try events.reduce(into: Data()) { $0.append(try FlowJournal.line(for: $1)) }

        let decoded = FlowJournal.events(in: data)
        #expect(decoded.events == events)
        #expect(decoded.consumed == data.count)
    }

    @Test("a trailing partial line is left for the next read")
    func partialLine() throws {
        let complete = try FlowJournal.line(for: event())
        let partial = try FlowJournal.line(for: event()).dropLast(10)

        let decoded = FlowJournal.events(in: complete + partial)
        #expect(decoded.events.count == 1)
        #expect(decoded.consumed == complete.count)
        #expect(FlowJournal.events(in: Data(partial)).consumed == 0)
    }

    @Test("lines that aren't events are skipped")
    func invalidLines() throws {
        let valid = try FlowJournal.line(for: event())
        let data = Data("not json\n{\"flowID\":1}\n\n".utf8) + valid
        let decoded = FlowJournal.events(in: data)
        #expect(decoded.events.count == 1)
        #expect(decoded.consumed == data.count)
    }

    // MARK: Writing and reading

    @Test("the reader returns only what was written since the last read")
    func incrementalReads() throws {
        try withTemporaryDirectory { directory in
            let writer = FlowJournalWriter(directory: directory)
            var reader = FlowJournalReader(directory: directory)
            #expect(reader.readNewEvents().isEmpty)

            let first = [event(), event()]
            first.forEach(writer.append)
            #expect(reader.readNewEvents() == first)
            #expect(reader.readNewEvents().isEmpty)

            let second = event(.closed)
            writer.append(second)
            #expect(reader.readNewEvents() == [second])
        }
    }

    @Test("the first read includes everything already in the journal")
    func firstReadHasHistory() throws {
        try withTemporaryDirectory { directory in
            let first = event()
            // Rotates after the second line, so the history spans both files.
            let writer = FlowJournalWriter(directory: directory, maxFileSize: try FlowJournal.line(for: first).count + 1)
            let events = [first, event(), event()]
            events.forEach(writer.append)

            var reader = FlowJournalReader(directory: directory)
            #expect(reader.readNewEvents() == events)
        }
    }

    @Test("the reader finishes a rotated file before moving to the new one")
    func followsRotation() throws {
        try withTemporaryDirectory { directory in
            let first = event()
            let writer = FlowJournalWriter(directory: directory, maxFileSize: try FlowJournal.line(for: first).count + 1)
            var reader = FlowJournalReader(directory: directory)

            writer.append(first)
            #expect(reader.readNewEvents() == [first])

            // The second line fills the file, which is rotated; the third starts a new one.
            let later = [event(), event()]
            later.forEach(writer.append)
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(FlowJournal.rotatedFileName).path))
            #expect(reader.readNewEvents() == later)
            #expect(reader.readNewEvents().isEmpty)
        }
    }

    @Test("the reader keeps up when every line is rotated out")
    func rotatesEveryLine() throws {
        try withTemporaryDirectory { directory in
            let writer = FlowJournalWriter(directory: directory, maxFileSize: 1)
            var reader = FlowJournalReader(directory: directory)
            for _ in 0..<3 {
                let next = event()
                writer.append(next)
                #expect(reader.readNewEvents() == [next])
            }
        }
    }

    @Test("a writer appends to an existing journal")
    func reopensJournal() throws {
        try withTemporaryDirectory { directory in
            let events = [event(), event()]
            FlowJournalWriter(directory: directory).append(events[0])
            FlowJournalWriter(directory: directory).append(events[1])

            var reader = FlowJournalReader(directory: directory)
            #expect(reader.readNewEvents() == events)
        }
    }
}
