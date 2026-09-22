import Testing
@testable import NetworkInspectorKit

@Suite("Formatting")
struct FormattingTests {
    @Test(
        "duration formats sub-second values in milliseconds",
        arguments: [
            (0.0, "0 ms"),
            (0.001, "1 ms"),
            (0.084, "84 ms"),
            (0.5, "500 ms"),
            (0.999, "999 ms")
        ]
    )
    func durationMilliseconds(seconds: Double, expected: String) {
        #expect(Formatting.duration(seconds: seconds) == expected)
    }

    @Test(
        "duration formats second-and-above values with one fractional digit",
        arguments: [
            (1.0, "1 s"),
            (1.2, "1.2 s"),
            (4.7, "4.7 s"),
            (60.0, "60 s")
        ]
    )
    func durationSeconds(seconds: Double, expected: String) {
        #expect(Formatting.duration(seconds: seconds) == expected)
    }

    @Test("duration rejects negative or non-finite values")
    func durationInvalid() {
        #expect(Formatting.duration(seconds: -1) == "—")
        #expect(Formatting.duration(seconds: .nan) == "—")
        #expect(Formatting.duration(seconds: .infinity) == "—")
    }

    @Test(
        "byte size formats across binary unit boundaries",
        arguments: [
            (0, "0 B"),
            (512, "512 B"),
            (1_024, "1 KB"),
            (1_536, "1.5 KB"),
            (1_048_576, "1 MB"),
            (1_572_864, "1.5 MB"),
            (1_073_741_824, "1 GB")
        ]
    )
    func byteSize(bytes: Int, expected: String) {
        #expect(Formatting.byteSize(bytes) == expected)
    }

    @Test("byte size rejects negative values")
    func byteSizeInvalid() {
        #expect(Formatting.byteSize(-1) == "—")
    }
}
