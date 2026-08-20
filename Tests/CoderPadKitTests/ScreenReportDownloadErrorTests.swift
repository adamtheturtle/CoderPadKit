//
//  ScreenReportDownloadErrorTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Screen report download errors")
struct ScreenReportDownloadErrorTests {
    @Test
    func `an unreadable report error body preserves unauthorized status semantics`() {
        let missing = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let body = ScreenClient.reportErrorBody(at: missing)
        #expect(body.isEmpty)

        let error = CoderPadError.http(403, body)
        #expect(error.isUnauthorized)
    }

    @Test
    func `a missing success report file maps to CoderPadError`() throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://www.codingame.com/assessment/api/v1.1/tests/1/report")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/pdf"]
        ))

        let error = #expect(throws: CoderPadError.self) {
            _ = try ScreenClient.reportSuccessData(at: missing, response: response)
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error, got \(String(describing: error))")
            return
        }
        #expect(detail == "The report response could not be read.")
    }

    @Test
    func `an oversized staged report still uses the decode taxonomy`() throws {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data(repeating: 0x25, count: 64).write(to: fileURL)
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://www.codingame.com/assessment/api/v1.1/tests/1/report")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/pdf",
                "Content-Length": String(ScreenReportFiles.maxReportBytes + 1)
            ]
        ))

        let error = #expect(throws: CoderPadError.self) {
            _ = try ScreenClient.reportSuccessData(at: fileURL, response: response)
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error, got \(String(describing: error))")
            return
        }
        #expect(detail == "The report is too large to open.")
    }
}

@Suite("Screen full-list pagination ceilings")
struct ScreenFullListPaginationCeilingTests {
    @Test
    func `page and item ceilings agree at the documented page maximum`() {
        #expect(ScreenClient.maximumPageSize == 50)
        #expect(
            ScreenClient.maximumFullListPages * ScreenClient.maximumPageSize
                >= ScreenClient.maximumFullListItems
        )
        #expect(ScreenClient.maximumFullListPages == 200)
        #expect(ScreenClient.maximumFullListItems == 10000)
    }

    @Test
    func `listAllTests requests the documented page maximum`() async throws {
        ListAllTestsLimitCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ListAllTestsLimitCaptureURLProtocol.self]
        let client = ScreenClient(
            apiKey: "key",
            baseURL: URL(string: "https://www.codingame.com")!,
            session: URLSession(configuration: configuration)
        )

        _ = try await client.listAllTests()

        let limits = ListAllTestsLimitCaptureURLProtocol.capturedLimits()
        #expect(!limits.isEmpty)
        #expect(limits.allSatisfy { $0 == String(ScreenClient.maximumPageSize) })
    }
}

private final nonisolated class ListAllTestsLimitCaptureURLProtocol: URLProtocol {
    private static let limits = Mutex<[String]>([])

    static func reset() {
        limits.withLock { $0 = [] }
    }

    static func capturedLimits() -> [String] {
        limits.withLock { $0 }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let components = request.url.flatMap({
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }) {
            let limit = components.queryItems?.first(where: { $0.name == "limit" })?.value
            Self.limits.withLock { $0.append(limit ?? "<missing>") }
        }

        let body = Data(#"""
        {"tests":[],"pagination":{"start":0,"limit":50,"total":0,"has_more_items":false}}
        """#.utf8)
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
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
