//
//  RawAPITests.swift
//  CoderPadKitTests
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Raw Interview API transport")
struct RawAPITests {
    private let client = CoderPadClient.mock(key: "raw-\(UUID().uuidString)")

    @Test
    func `preserves response bytes and status`() async throws {
        let response = try await client.rawRequest(
            path: "/api/quota",
            responseLimit: 64 * 1024
        )

        #expect(response.status == 200)
        #expect(response.isSuccessful)
        let object = try #require(
            JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        )
        #expect(object["pads_used"] as? Int == 187)
    }

    @Test
    func `enforces the response limit`() async {
        let error = await #expect(throws: CoderPadResponseTooLargeError.self) {
            _ = try await client.rawRequest(path: "/api/quota", responseLimit: 1)
        }
        #expect(error?.limit == 1)
    }

    @Test
    func `preserves valueless empty duplicate and literal plus query items`() async throws {
        RawQueryCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RawQueryCaptureURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "key",
            baseURL: URL(string: "https://example.test/gateway")!,
            session: URLSession(configuration: configuration)
        )

        _ = try await client.rawRequest(
            path: "/api/items",
            query: [
                URLQueryItem(name: "flag", value: nil),
                URLQueryItem(name: "empty", value: ""),
                URLQueryItem(name: "collision", value: "request"),
                URLQueryItem(name: "collision", value: "cursor+one=next/&"),
                URLQueryItem(name: "text", value: "C++"),
                URLQueryItem(name: "label+key", value: "%2B")
            ],
            responseLimit: 1024
        )

        let url = try #require(RawQueryCaptureURLProtocol.capturedURL())
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery == "flag&empty=&collision=request"
            + "&collision=cursor%2Bone%3Dnext/%26&text=C%2B%2B&label%2Bkey=%252B")
        #expect(components.queryItems == [
            URLQueryItem(name: "flag", value: nil),
            URLQueryItem(name: "empty", value: ""),
            URLQueryItem(name: "collision", value: "request"),
            URLQueryItem(name: "collision", value: "cursor+one=next/&"),
            URLQueryItem(name: "text", value: "C++"),
            URLQueryItem(name: "label+key", value: "%2B")
        ])
    }
}

private final nonisolated class RawQueryCaptureURLProtocol: URLProtocol {
    private static let captured = Mutex<URL?>(nil)

    static func reset() {
        captured.withLock { $0 = nil }
    }

    static func capturedURL() -> URL? {
        captured.withLock { $0 }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.captured.withLock { $0 = request.url }
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
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
