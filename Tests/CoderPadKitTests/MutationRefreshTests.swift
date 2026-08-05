//
//  MutationRefreshTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import Foundation
import Synchronization
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Mutation refresh outcomes", .serialized)
struct MutationRefreshTests {
    @Test
    func `pad update distinguishes a committed write from a failed refresh`() async throws {
        let client = makeClient()

        let error = await #expect(throws: CoderPadMutationRefreshError.self) {
            _ = try await client.updatePad(PadUpdate(id: "PAD123", title: "Committed"))
        }

        #expect(error?.target == .pad(id: "PAD123"))
        #expect(isNotFound(error?.refreshError))
        #expect(MutationRefreshURLProtocol.methods() == ["PUT", "GET"])
    }

    @Test
    func `question updates distinguish a committed write from a failed refresh`() async throws {
        let client = makeClient()

        let jsonError = await #expect(throws: CoderPadMutationRefreshError.self) {
            _ = try await client.updateQuestion(QuestionUpdate(id: 42, title: "Committed"))
        }
        #expect(jsonError?.target == .question(id: 42))
        #expect(isNotFound(jsonError?.refreshError))

        MutationRefreshURLProtocol.reset()
        let zipError = await #expect(throws: CoderPadMutationRefreshError.self) {
            _ = try await client.updateQuestion(
                QuestionUpdate(id: 42, title: "Committed ZIP"),
                zipFile: QuestionZIPUpload(data: Data([0x50, 0x4B]), filename: "question.zip")
            )
        }
        #expect(zipError?.target == .question(id: 42))
        #expect(isNotFound(zipError?.refreshError))
        #expect(MutationRefreshURLProtocol.methods() == ["PUT", "GET"])
    }

    private func makeClient() -> CoderPadClient {
        MutationRefreshURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MutationRefreshURLProtocol.self]
        return CoderPadClient(
            apiKey: "key",
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func isNotFound(_ error: CoderPadError?) -> Bool {
        guard case .http(404, _) = error else { return false }
        return true
    }
}

private final nonisolated class MutationRefreshURLProtocol: URLProtocol {
    private static let capturedMethods = Mutex<[String]>([])

    static func reset() {
        capturedMethods.withLock { $0.removeAll() }
    }

    static func methods() -> [String] {
        capturedMethods.withLock { $0 }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let method = request.httpMethod ?? ""
        Self.capturedMethods.withLock { $0.append(method) }
        let status = method == "PUT" ? 200 : 404
        let body = method == "PUT"
            ? Data(#"{"status":"OK"}"#.utf8)
            : Data(#"{"message":"refresh unavailable"}"#.utf8)
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: status,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
