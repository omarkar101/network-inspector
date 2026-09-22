import Testing
@testable import NetworkInspectorKit

@Suite("HTTPStatus")
struct HTTPStatusTests {
    @Test(
        "classifies known ranges",
        arguments: [
            (100, HTTPStatusClass.informational),
            (101, .informational),
            (199, .informational),
            (200, .success),
            (201, .success),
            (299, .success),
            (300, .redirection),
            (304, .redirection),
            (399, .redirection),
            (400, .clientError),
            (404, .clientError),
            (422, .clientError),
            (499, .clientError),
            (500, .serverError),
            (503, .serverError),
            (599, .serverError),
            (0, .unknown),
            (99, .unknown),
            (600, .unknown),
            (-1, .unknown)
        ]
    )
    func classifiesKnownRanges(code: Int, expected: HTTPStatusClass) {
        #expect(HTTPStatus.classify(code) == expected)
    }

    @Test(
        "failure flag matches client/server error classes",
        arguments: [200, 201, 304, 400, 404, 500, 0, 700]
    )
    func failureFlag(code: Int) {
        let expected = switch HTTPStatus.classify(code) {
        case .clientError, .serverError, .unknown: true
        case .informational, .success, .redirection: false
        }
        #expect(HTTPStatus.isFailure(code) == expected)
    }
}
