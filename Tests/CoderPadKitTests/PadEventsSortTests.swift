//
//  PadEventsSortTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import Foundation
import Testing

@Suite("Pad events sorting", .serialized)
struct PadEventsSortTests {
    @Test
    func `padEvents forwards the sort query like other Interview list endpoints`() async throws {
        SortCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SortCaptureURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "secret",
            session: URLSession(configuration: configuration)
        )

        _ = try await client.padEvents(padID: "DEMOABC1", sort: "created_at,asc")

        let url = try #require(SortCaptureURLProtocol.lastURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains { $0.name == "sort" && $0.value == "created_at,asc" })
    }

    @Test
    func `padEvents omits sort when callers leave the default`() async throws {
        SortCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SortCaptureURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "secret",
            session: URLSession(configuration: configuration)
        )

        _ = try await client.padEvents(padID: "DEMOABC1")

        let url = try #require(SortCaptureURLProtocol.lastURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(!items.contains { $0.name == "sort" })
    }
}

private final nonisolated class SortCaptureURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var capturedURL: URL?

    static var lastURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return capturedURL
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        capturedURL = nil
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.capturedURL = request.url
        Self.lock.unlock()

        let body = Data(#"{"status":"OK","events":[],"total":0}"#.utf8)
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
