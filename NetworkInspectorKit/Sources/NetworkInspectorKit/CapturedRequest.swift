import Foundation

/// HTTP verbs recognized by the inspector.
public enum HTTPMethod: String, Sendable, Hashable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// A single captured HTTP request/response pair, as a network inspector would
/// display in its list of traffic.
public struct CapturedRequest: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let method: HTTPMethod
    public let url: String
    public let statusCode: Int
    public let durationSeconds: Double
    public let requestBodySize: Int
    public let responseBodySize: Int
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        method: HTTPMethod,
        url: String,
        statusCode: Int,
        durationSeconds: Double,
        requestBodySize: Int,
        responseBodySize: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationSeconds = durationSeconds
        self.requestBodySize = requestBodySize
        self.responseBodySize = responseBodySize
        self.timestamp = timestamp
    }

    /// The RFC 9110 classification of this entry's status code.
    public var statusClass: HTTPStatusClass {
        HTTPStatus.classify(statusCode)
    }

    /// Whether this entry represents a failed request (4xx/5xx or unparsable status).
    public var isFailure: Bool {
        HTTPStatus.isFailure(statusCode)
    }

    /// A short, formatted duration string, e.g. "234 ms" or "1.2 s".
    public var formattedDuration: String {
        Formatting.duration(seconds: durationSeconds)
    }

    /// A short, formatted response size string, e.g. "1.5 KB".
    public var formattedResponseSize: String {
        Formatting.byteSize(responseBodySize)
    }

    /// A short, formatted request size string, e.g. "512 B".
    public var formattedRequestSize: String {
        Formatting.byteSize(requestBodySize)
    }
}

extension Sequence<CapturedRequest> {
    /// Filters entries by a case-insensitive substring match against the URL
    /// and HTTP method, and/or by status class. An empty query with a `nil`
    /// class matches everything.
    public func matching(query: String, statusClass: HTTPStatusClass? = nil) -> [CapturedRequest] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return filter { entry in
            if let statusClass, entry.statusClass != statusClass {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return entry.url.localizedCaseInsensitiveContains(trimmed)
                || entry.method.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Entries sorted newest first.
    public func sortedByRecency() -> [CapturedRequest] {
        sorted { $0.timestamp > $1.timestamp }
    }
}
