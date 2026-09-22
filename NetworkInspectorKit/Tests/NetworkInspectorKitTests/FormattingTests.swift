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
        "byte size starts at KB, then steps up to MB and GB",
        arguments: [
            (0, "0 KB"),
            (1, "<0.1 KB"),
            (512, "0.5 KB"),
            (1_024, "1 KB"),
            (1_536, "1.5 KB"),
            (10_240, "10 KB"),
            (153_600, "150 KB"),
            (1_048_064, "1 MB"),       // 1023.5 KB displays as 1024 -> promoted
            (1_047_552, "1023 KB"),
            (1_048_576, "1 MB"),
            (1_572_864, "1.5 MB"),
            (524_288_000, "500 MB"),
            (1_073_741_824, "1 GB"),
            (2_684_354_560, "2.5 GB")
        ]
    )
    func byteSize(bytes: Int, expected: String) {
        #expect(Formatting.byteSize(bytes) == expected)
    }

    @Test("byte size rejects negative values")
    func byteSizeInvalid() {
        #expect(Formatting.byteSize(-1) == "—")
    }

    @Test(
        "percent rounds to whole percentages",
        arguments: [
            (0.0, "0%"),
            (0.001, "<1%"),
            (0.005, "1%"),
            (0.125, "13%"),
            (0.5, "50%"),
            (1.0, "100%")
        ]
    )
    func percent(fraction: Double, expected: String) {
        #expect(Formatting.percent(fraction) == expected)
    }

    @Test("percent rejects negative or non-finite values")
    func percentInvalid() {
        #expect(Formatting.percent(-0.1) == "—")
        #expect(Formatting.percent(.nan) == "—")
    }

    @Test(
        "rate shows one decimal below ten per minute",
        arguments: [
            (0.0, "0/min"),
            (2.5, "2.5/min"),
            (3.0, "3/min"),
            (9.94, "9.9/min"),
            (9.96, "10/min"),
            (12.4, "12/min"),
            (120.6, "121/min")
        ]
    )
    func rate(perMinute: Double, expected: String) {
        #expect(Formatting.rate(perMinute: perMinute) == expected)
    }

    @Test("rate rejects negative or non-finite values")
    func rateInvalid() {
        #expect(Formatting.rate(perMinute: -1) == "—")
        #expect(Formatting.rate(perMinute: .infinity) == "—")
    }

    @Test(
        "speed uses the same KB, MB, GB steps per second",
        arguments: [
            (0.0, "0 KB/s"),
            (512.0, "0.5 KB/s"),
            (870_400.0, "850 KB/s"),
            (2_516_582.4, "2.4 MB/s"),
            (1_073_741_824.0, "1 GB/s")
        ]
    )
    func speed(bytesPerSecond: Double, expected: String) {
        #expect(Formatting.speed(bytesPerSecond: bytesPerSecond) == expected)
    }

    @Test("speed rejects negative or non-finite values")
    func speedInvalid() {
        #expect(Formatting.speed(bytesPerSecond: -1) == "—")
        #expect(Formatting.speed(bytesPerSecond: .nan) == "—")
    }

    @Test("byte sizes never fall back to plain bytes", arguments: [0, 1, 100, 1_000, 1_023])
    func noPlainBytes(bytes: Int) {
        #expect(!Formatting.byteSize(bytes).hasSuffix(" B"))
    }
}
