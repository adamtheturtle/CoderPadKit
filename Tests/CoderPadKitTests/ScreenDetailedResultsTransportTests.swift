@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Detailed Screen result transport")
struct ScreenDetailedResultsTransportTests {
    @Test(arguments: [false, true])
    func `detail uses one JSON request without downloading candidate media`(community: Bool) async throws {
        let key = "200-\(UUID().uuidString)"
        let client = client(key)
        let result = try await client.getTest(id: 5001, withCommunityStats: community)
        #expect(result.detailedQuestions.count == 8)
        #expect(result.report?.markedAsCheatedByRecruiter == false)
        #expect(result.report?.timeSpentOutsideEnvironmentSeconds == 0)
        #expect(result.report?.environmentExitCount == 0)
        let requests = DetailedResultsURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        let suffix = community ? "?withCommunityStats=true" : ""
        #expect(request.url?.absoluteString == "https://screen.coderpad.io/assessment/api/v1.1/tests/5001" + suffix)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "API-Key") == key)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.httpBody == nil)
    }

    @Test(arguments: [400, 403, 404])
    func `detail errors retain status and bounded server body`(status: Int) async throws {
        let key = "\(status)-\(UUID().uuidString)"
        do {
            _ = try await client(key).getTest(id: 5001)
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case let .http(code, body) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == status)
            #expect(body == #"{"code":"FeatureNotAvailable"}"#)
        }
        #expect(DetailedResultsURLProtocol.requests.withLock { $0.removeValue(forKey: key)?.count } == 1)
    }

    private func client(_ key: String) -> ScreenClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DetailedResultsURLProtocol.self]
        return ScreenClient(apiKey: key, session: URLSession(configuration: configuration))
    }
}

private final nonisolated class DetailedResultsURLProtocol: URLProtocol {
    static let requests = Mutex<[String: [URLRequest]]>([:])

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "API-Key") ?? ""
        Self.requests.withLock { $0[key, default: []].append(request) }
        let status = Int(key.split(separator: "-").first ?? "") ?? 500
        let payload: [String: Any] = status == 200 ? [
            "id": 5001, "status": "need review", "questions": MockScreenFixtures.detailedQuestions(),
            "report": ["marked_as_cheated_by_recruiter": false,
                       "time_spent_outside_environment_seconds": 0, "environment_exit_count": 0]
        ] : ["code": "FeatureNotAvailable"]
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]),
              let body = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
