//
//  InterviewBaseURLValidationTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Interview base URL validation")
struct InterviewBaseURLValidationTests {
    @Test
    func `default and path-prefixed HTTPS origins are accepted`() {
        #expect(CoderPadClient.isAllowedBaseURL(CoderPadClient.defaultBaseURL))
        #expect(CoderPadClient.isAllowedBaseURL(URL(string: "https://coderpad.example/prefix")!))
        #expect(CoderPadClient.isAllowedBaseURL(URL(string: "https://example.com")!))
    }

    @Test(arguments: [
        "http://app.coderpad.io",
        "https://user@app.coderpad.io",
        "https://user:pass@app.coderpad.io",
        "https://app.coderpad.io?tenant=a",
        "https://app.coderpad.io#section",
        "https://app.coderpad.io/path?tenant=a",
        "https://app.coderpad.io/path#section"
    ])
    func `insecure credential-bearing and query-fragment bases are rejected`(raw: String) {
        #expect(!CoderPadClient.isAllowedBaseURL(URL(string: raw)!))
    }
}
