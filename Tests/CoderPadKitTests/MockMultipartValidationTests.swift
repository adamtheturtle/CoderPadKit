//
//  MockMultipartValidationTests.swift
//  CoderPadKitTests
//

import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock multipart validation")
struct MockMultipartValidationTests {
    @Test
    func `a truncated multipart question body returns a client error`() async throws {
        let boundary = "truncated-boundary"
        var request = URLRequest(url: URL(string: "https://app.coderpad.io/api/questions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer test-\(UUID().uuidString)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"question[title]\"\r\n\r\nTruncated".utf8
        )

        let (data, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)

        #expect(http.statusCode == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("malformed multipart body"))
    }
}
