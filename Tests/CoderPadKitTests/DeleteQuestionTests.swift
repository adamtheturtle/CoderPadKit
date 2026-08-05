import CoderPadKit
import Foundation
import Testing

@Suite("Question deletion responses")
struct DeleteQuestionTests {
    @Test(arguments: [204, 200])
    func `empty and JSON success responses both succeed`(id: Int) async throws {
        try await client().deleteQuestion(id: id)
    }

    @Test
    func `non-success responses retain their mapped status and body`() async throws {
        let error = await #expect(throws: CoderPadError.self) {
            try await client().deleteQuestion(id: 409)
        }

        guard case let .http(status, body) = error else {
            Issue.record("Expected a mapped HTTP error")
            return
        }
        #expect(status == 409)
        #expect(body.contains("conflict"))
    }

    private func client() -> CoderPadClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeleteQuestionURLProtocol.self]
        return CoderPadClient(apiKey: "key", session: URLSession(configuration: configuration))
    }
}

private final nonisolated class DeleteQuestionURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard request.httpMethod == "DELETE",
              request.value(forHTTPHeaderField: "Authorization") == "Bearer key",
              let url = request.url,
              let id = Int(url.lastPathComponent) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let status = id == 204 ? 204 : id == 200 ? 200 : 409
        let data = switch status {
        case 204: Data()
        case 200: Data(#"{"status":"OK"}"#.utf8)
        default: Data(#"{"error":"conflict"}"#.utf8)
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
