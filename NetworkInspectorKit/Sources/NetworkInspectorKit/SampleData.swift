import Foundation

/// Sample captured requests for previews and for the app's initial, empty-state list.
public enum SampleData {
    public static let capturedRequests: [CapturedRequest] = [
        CapturedRequest(
            method: .get,
            url: "https://api.example.com/v1/users/42",
            statusCode: 200,
            durationSeconds: 0.084,
            requestBodySize: 0,
            responseBodySize: 1_842,
            timestamp: Date(timeIntervalSinceNow: -12)
        ),
        CapturedRequest(
            method: .post,
            url: "https://api.example.com/v1/sessions",
            statusCode: 201,
            durationSeconds: 0.312,
            requestBodySize: 256,
            responseBodySize: 128,
            timestamp: Date(timeIntervalSinceNow: -48)
        ),
        CapturedRequest(
            method: .get,
            url: "https://cdn.example.com/assets/logo.png",
            statusCode: 304,
            durationSeconds: 0.021,
            requestBodySize: 0,
            responseBodySize: 0,
            timestamp: Date(timeIntervalSinceNow: -90)
        ),
        CapturedRequest(
            method: .patch,
            url: "https://api.example.com/v1/users/42/preferences",
            statusCode: 422,
            durationSeconds: 0.156,
            requestBodySize: 512,
            responseBodySize: 340,
            timestamp: Date(timeIntervalSinceNow: -160)
        ),
        CapturedRequest(
            method: .get,
            url: "https://api.example.com/v1/reports/summary",
            statusCode: 500,
            durationSeconds: 4.7,
            requestBodySize: 0,
            responseBodySize: 96,
            timestamp: Date(timeIntervalSinceNow: -240)
        ),
        CapturedRequest(
            method: .delete,
            url: "https://api.example.com/v1/cache/entries/9",
            statusCode: 204,
            durationSeconds: 0.043,
            requestBodySize: 0,
            responseBodySize: 0,
            timestamp: Date(timeIntervalSinceNow: -310)
        ),
        CapturedRequest(
            method: .get,
            url: "https://api.example.com/v1/nonexistent",
            statusCode: 404,
            durationSeconds: 0.067,
            requestBodySize: 0,
            responseBodySize: 58,
            timestamp: Date(timeIntervalSinceNow: -400)
        )
    ]
}
