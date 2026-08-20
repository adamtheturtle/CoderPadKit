//
//  RawHTTPMethodValidationTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Raw HTTP method validation")
struct RawHTTPMethodValidationTests {
    @Test(arguments: ["GET", "post", "PATCH", "DELETE", "OPTIONS"])
    func `accepts and uppercases RFC tokens`(method: String) throws {
        #expect(try CoderPadClient.validatedHTTPMethod(method) == method.uppercased())
    }

    @Test(arguments: [
        "",
        " ",
        " GET",
        "GET ",
        "G ET",
        "GET\r\nX-Injected: 1",
        "GET\n",
        "GET\r",
        "GET\t",
        "GET/1.1",
        "GET:HEAD"
    ])
    func `rejects empty whitespace and header-like methods`(method: String) {
        #expect(throws: CoderPadError.self) {
            _ = try CoderPadClient.validatedHTTPMethod(method)
        }
    }

    @Test
    func `rawRequest rejects an invalid method before transport`() async {
        let client = CoderPadClient(apiKey: "key", session: URLSession(configuration: .ephemeral))
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.rawRequest(
                method: "GET\r\nX-Evil: 1",
                path: "/api/quota",
                responseLimit: 1024
            )
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a .decode error, got \(String(describing: error))")
            return
        }
        #expect(detail.contains("HTTP method"))
    }
}
