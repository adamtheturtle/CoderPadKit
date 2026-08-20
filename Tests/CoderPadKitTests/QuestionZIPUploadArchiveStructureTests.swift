//
//  QuestionZIPUploadArchiveStructureTests.swift
//  CoderPadKitTests
//
//  Split from QuestionZIPUploadTests.swift to keep it under SwiftLint's
//  type_body_length limit. Uses its own request counter rather than sharing
//  QuestionZIPUploadTests' fixture, so the two suites can run in parallel
//  without racing on shared mutable state.
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Question ZIP upload archive structure")
struct QuestionZIPUploadArchiveStructureTests {
    @Test(
        arguments: [
            Data(),
            Data([0x00, 0x01, 0x02, 0x03]),
            Data("not a zip".utf8),
            Data([0x50, 0x4B])
        ]
    )
    func `data without a minimally valid ZIP signature is rejected before staging`(_ data: Data) async {
        let (client, identifier) = makeClient()
        let error = await #expect(throws: QuestionZIPUploadInvalidArchiveError.self) {
            _ = try await client.createQuestion(
                QuestionCreate(title: "Bad archive"),
                zipFile: QuestionZIPUpload(data: data, filename: "bad.zip")
            )
        }
        #expect(error?.byteCount == data.count)
        #expect(ArchiveStructureCaptureURLProtocol.requestCount(for: identifier) == 0)
    }

    @Test
    func `an empty archive's end-of-central-directory record is accepted`() async throws {
        let (client, identifier) = makeClient()
        let emptyArchive = Data([0x50, 0x4B, 0x05, 0x06] + [UInt8](repeating: 0, count: 18))

        _ = try await client.createQuestion(
            QuestionCreate(title: "Empty archive"),
            zipFile: QuestionZIPUpload(data: emptyArchive, filename: "empty.zip")
        )

        #expect(ArchiveStructureCaptureURLProtocol.requestCount(for: identifier) == 1)
    }

    private func makeClient() -> (client: CoderPadClient, identifier: String) {
        let identifier = UUID().uuidString
        ArchiveStructureCaptureURLProtocol.register(identifier: identifier)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ArchiveStructureCaptureURLProtocol.self]
        configuration.httpAdditionalHeaders = [ArchiveStructureCaptureURLProtocol.identifierHeader: identifier]
        let client = CoderPadClient(
            apiKey: "test-key",
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration)
        )
        return (client, identifier)
    }
}

/// Counts requests per test, keyed by a per-client identifier header, so tests can
/// run concurrently without a shared mutable counter racing between them.
private final nonisolated class ArchiveStructureCaptureURLProtocol: URLProtocol {
    static let identifierHeader = "X-Test-Client-Identifier"
    private static let counts = Mutex<[String: Int]>([:])

    static func register(identifier: String) {
        counts.withLock { $0[identifier] = 0 }
    }

    private static func increment(identifier: String) {
        counts.withLock { $0[identifier, default: 0] += 1 }
    }

    static func requestCount(for identifier: String) -> Int {
        counts.withLock { $0[identifier, default: 0] }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if let identifier = request.value(forHTTPHeaderField: Self.identifierHeader) {
            Self.increment(identifier: identifier)
        }

        let responseBody = Data(#"{"id":42,"title":"Captured"}"#.utf8)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
