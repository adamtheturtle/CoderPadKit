//
//  ScreenResponseLimitTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen response limits")
struct ScreenResponseLimitTests {
    @Test
    func `an oversized success body stops with a mapped decode error`() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedScreenResponseURLProtocol.self]
        let client = ScreenClient(
            apiKey: "key",
            session: URLSession(configuration: configuration),
            maximumResponseBodyBytes: 8
        )

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.listCampaigns()
        }

        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error")
            return
        }
        #expect(detail == "The Screen response exceeded the 8-byte limit.")
    }

    @Test
    func `a declared oversized success Content-Length fails before loading the body`() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedScreenResponseURLProtocol.self]
        let client = ScreenClient(
            apiKey: "key",
            session: URLSession(configuration: configuration),
            maximumResponseBodyBytes: 8
        )

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.listCampaigns()
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error, got \(String(describing: error))")
            return
        }
        #expect(detail == "The Screen response exceeded the 8-byte limit.")
    }
}

private final nonisolated class OversizedScreenResponseURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: nil
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 97, count: 32))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final nonisolated class OversizedScreenResponseURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Length": "64"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 97, count: 64))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
