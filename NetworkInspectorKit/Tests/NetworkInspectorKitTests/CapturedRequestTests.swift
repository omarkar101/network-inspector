import Foundation
import Testing
@testable import NetworkInspectorKit

@Suite("CapturedRequest")
struct CapturedRequestTests {
    private func makeEntry(
        method: HTTPMethod = .get,
        url: String = "https://api.example.com/v1/users",
        statusCode: Int = 200,
        durationSeconds: Double = 0.1,
        requestBodySize: Int = 0,
        responseBodySize: Int = 100,
        timestamp: Date = Date()
    ) -> CapturedRequest {
        CapturedRequest(
            method: method,
            url: url,
            statusCode: statusCode,
            durationSeconds: durationSeconds,
            requestBodySize: requestBodySize,
            responseBodySize: responseBodySize,
            timestamp: timestamp
        )
    }

    @Test("derived properties reflect the status code")
    func derivedProperties() {
        let ok = makeEntry(statusCode: 200)
        #expect(ok.statusClass == .success)
        #expect(ok.isFailure == false)

        let failed = makeEntry(statusCode: 500)
        #expect(failed.statusClass == .serverError)
        #expect(failed.isFailure == true)
    }

    @Test("formatted fields delegate to Formatting")
    func formattedFields() {
        let entry = makeEntry(durationSeconds: 1.2, requestBodySize: 512, responseBodySize: 1_536)
        #expect(entry.formattedDuration == Formatting.duration(seconds: 1.2))
        #expect(entry.formattedRequestSize == Formatting.byteSize(512))
        #expect(entry.formattedResponseSize == Formatting.byteSize(1_536))
    }

    @Test("matching filters by URL or method substring, case-insensitively")
    func matchingByText() {
        let entries = [
            makeEntry(method: .get, url: "https://api.example.com/v1/users"),
            makeEntry(method: .post, url: "https://api.example.com/v1/sessions"),
            makeEntry(method: .delete, url: "https://cdn.example.com/assets/logo.png")
        ]

        #expect(entries.matching(query: "users").count == 1)
        #expect(entries.matching(query: "USERS").count == 1)
        #expect(entries.matching(query: "post").count == 1)
        #expect(entries.matching(query: "cdn").count == 1)
        #expect(entries.matching(query: "").count == 3)
        #expect(entries.matching(query: "nonexistent-path").isEmpty)
    }

    @Test("matching filters by status class")
    func matchingByStatusClass() {
        let entries = [
            makeEntry(statusCode: 200),
            makeEntry(statusCode: 404),
            makeEntry(statusCode: 500)
        ]

        #expect(entries.matching(query: "", statusClass: .clientError).count == 1)
        #expect(entries.matching(query: "", statusClass: .serverError).count == 1)
        #expect(entries.matching(query: "", statusClass: .success).count == 1)
    }

    @Test("matching combines text and status class filters")
    func matchingCombined() {
        let entries = [
            makeEntry(url: "https://api.example.com/v1/users", statusCode: 200),
            makeEntry(url: "https://api.example.com/v1/users/1", statusCode: 404)
        ]

        let result = entries.matching(query: "users", statusClass: .clientError)
        #expect(result.count == 1)
        #expect(result.first?.statusCode == 404)
    }

    @Test("sortedByRecency orders newest first")
    func sortedByRecency() {
        let older = makeEntry(timestamp: Date(timeIntervalSince1970: 0))
        let newer = makeEntry(timestamp: Date(timeIntervalSince1970: 1_000))
        let sorted = [older, newer].sortedByRecency()
        #expect(sorted.first?.id == newer.id)
        #expect(sorted.last?.id == older.id)
    }

    @Test("sample data is non-empty and includes both successes and failures")
    func sampleData() {
        #expect(!SampleData.capturedRequests.isEmpty)
        #expect(SampleData.capturedRequests.contains { !$0.isFailure })
        #expect(SampleData.capturedRequests.contains { $0.isFailure })
    }
}
