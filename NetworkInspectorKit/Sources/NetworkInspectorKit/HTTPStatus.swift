/// The classification of an HTTP status code, per RFC 9110 §15.
public enum HTTPStatusClass: String, Sendable, CaseIterable, Hashable {
    case informational
    case success
    case redirection
    case clientError
    case serverError
    case unknown

    /// A short, human-facing label for the class, suitable for a badge.
    public var label: String {
        switch self {
        case .informational: "Informational"
        case .success: "Success"
        case .redirection: "Redirection"
        case .clientError: "Client Error"
        case .serverError: "Server Error"
        case .unknown: "Unknown"
        }
    }
}

public enum HTTPStatus {
    /// Classifies a raw HTTP status code into its RFC 9110 category.
    ///
    /// Codes outside the valid 100...599 range are reported as `.unknown`.
    public static func classify(_ code: Int) -> HTTPStatusClass {
        switch code {
        case 100...199: .informational
        case 200...299: .success
        case 300...399: .redirection
        case 400...499: .clientError
        case 500...599: .serverError
        default: .unknown
        }
    }

    /// Whether a status code represents a failure worth flagging in a list (4xx/5xx, or out of range).
    public static func isFailure(_ code: Int) -> Bool {
        switch classify(code) {
        case .clientError, .serverError, .unknown: true
        case .informational, .success, .redirection: false
        }
    }
}
