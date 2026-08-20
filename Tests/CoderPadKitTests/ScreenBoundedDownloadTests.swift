//
//  ScreenBoundedDownloadTests.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Screen bounded downloads", .serialized)
struct ScreenBoundedDownloadTests {
    @Test
    func `an advertised oversized report is rejected before the body is kept`() async {
        DeclaredLengthURLProtocol.install(
            status: 200,
            contentLength: ScreenReportFiles.maxReportBytes + 1,
            body: Data(repeating: 0x25, count: 32)
        )
        defer { DeclaredLengthURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeclaredLengthURLProtocol.self]
        let client = ScreenClient(apiKey: "key", session: URLSession(configuration: configuration))

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.testReport(id: 1)
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error, got \(String(describing: error))")
            return
        }
        #expect(detail.contains("exceeded the"))
    }

    @Test
    func `an oversized error body is truncated to the configured ceiling`() async throws {
        let oversized = Data(repeating: UInt8(ascii: "e"), count: ScreenClient.maximumErrorBodyBytes + 64)
        DeclaredLengthURLProtocol.install(status: 500, contentLength: nil, body: oversized)
        defer { DeclaredLengthURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeclaredLengthURLProtocol.self]
        let client = ScreenClient(apiKey: "key", session: URLSession(configuration: configuration))

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.listCampaigns()
        }
        guard case let .http(status, body) = error else {
            Issue.record("Expected an .http error, got \(String(describing: error))")
            return
        }
        #expect(status == 500)
        #expect(body.utf8.count == ScreenClient.maximumErrorBodyBytes)
        #expect(body.allSatisfy { $0 == "e" })
    }
}

private nonisolated struct DeclaredLengthStub: Sendable {
    var status: Int
    var contentLength: Int?
    var body: Data
}

private final nonisolated class DeclaredLengthURLProtocol: URLProtocol {
    private static let stub = Mutex(
        DeclaredLengthStub(status: 500, contentLength: nil, body: Data())
    )

    static func install(status: Int, contentLength: Int?, body: Data) {
        stub.withLock {
            $0 = DeclaredLengthStub(status: status, contentLength: contentLength, body: body)
        }
    }

    static func reset() {
        stub.withLock {
            $0 = DeclaredLengthStub(status: 500, contentLength: nil, body: Data())
        }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let current = Self.stub.withLock { $0 }
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        var headers: [String: String] = ["Content-Type": "application/json"]
        if let contentLength = current.contentLength {
            headers["Content-Length"] = String(contentLength)
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: current.status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: current.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
