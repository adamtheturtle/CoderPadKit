//
//  RawAPITests.swift
//  CoderPadKitTests
//

import CoderPadKit
import CoderPadKitMock
import Foundation
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
        await #expect(throws: CoderPadResponseTooLargeError.self) {
            _ = try await client.rawRequest(path: "/api/quota", responseLimit: 1)
        }
    }
}
