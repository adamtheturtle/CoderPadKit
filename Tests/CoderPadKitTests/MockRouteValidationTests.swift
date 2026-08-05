//
//  MockRouteValidationTests.swift
//  CoderPadKitTests
//

import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock route validation")
struct MockRouteValidationTests {
    @Test(arguments: [
        ("GET", "/api/pad_environments/\(String(repeating: "9", count: 100))"),
        ("GET", "/api/questions/\(String(repeating: "9", count: 100))"),
        ("PUT", "/api/questions/\(String(repeating: "9", count: 100))"),
        ("DELETE", "/api/questions/\(String(repeating: "9", count: 100))")
    ])
    func `overflowing numeric path IDs return a client error`(method: String, path: String) async throws {
        var request = URLRequest(url: URL(string: "https://app.coderpad.io\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer test-\(UUID().uuidString)", forHTTPHeaderField: "Authorization")
        if method == "PUT" {
            request.httpBody = Data("{}".utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)

        #expect(http.statusCode == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("invalid"))
    }
}
