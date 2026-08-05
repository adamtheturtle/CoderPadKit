//
//  MockScreenMalformedJSONTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock Screen JSON validation")
struct MockScreenMalformedJSONTests {
    @Test(arguments: [
        "/campaigns/42/actions/send",
        "/webhook"
    ])
    func `malformed write bodies return a JSON 400`(_ path: String) async throws {
        let client = ScreenClient.mock(key: "malformed-json-\(UUID().uuidString)")
        var request = URLRequest(
            url: client.baseURL.appending(path: "/assessment/api/v1.1\(path)")
        )
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"unfinished":"#.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")

        let (data, response) = try await client.session.data(for: request)
        let http = try #require(response as? HTTPURLResponse)

        #expect(http.statusCode == 400)
        #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(String(decoding: data, as: UTF8.self).contains("invalid_json"))
    }

    @Test
    func `a malformed webhook body does not replace existing state`() async throws {
        let client = ScreenClient.mock(key: "malformed-webhook-\(UUID().uuidString)")
        try await client.setWebhookURL("https://example.com/kept")

        var request = URLRequest(
            url: client.baseURL.appending(path: "/assessment/api/v1.1/webhook")
        )
        request.httpMethod = "POST"
        request.httpBody = Data("not JSON".utf8)
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")
        _ = try await client.session.data(for: request)

        #expect(try await client.webhookURL() == "https://example.com/kept")
    }
}
