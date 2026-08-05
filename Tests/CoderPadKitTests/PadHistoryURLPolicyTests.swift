//
//  PadHistoryURLPolicyTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import Foundation
import Testing

@Suite("Pad history URL policy")
struct PadHistoryURLPolicyTests {
    private let hostedBase = URL(string: "https://app.coderpad.io")!

    private func allowed(_ url: String, baseURL: URL? = nil) -> Bool {
        PadHistoryURLPolicy.isAllowed(url, accountBaseURL: baseURL ?? hostedBase)
    }

    @Test
    func `supported CoderPad history origins are allowed`() {
        for shard in [1, 4, 9, 42, 10_000] {
            #expect(allowed("https://coderpad-\(shard).firebaseio.com/abc/history.json"))
        }
        #expect(allowed("https://coderpad-prod.europe-west1.firebasedatabase.app/abc/history.json"))
        #expect(allowed("https://app.coderpad.io/history/abc"))
        #expect(allowed("https://eu.app.coderpad.io/history/abc"))
    }

    @Test
    func `exact self-hosted HTTPS origin is allowed`() throws {
        let baseURL = try #require(URL(string: "https://coderpad.acme.internal:8443"))

        #expect(allowed("https://coderpad.acme.internal:8443/history/abc", baseURL: baseURL))
        #expect(!allowed("https://coderpad.acme.internal/history/abc", baseURL: baseURL))
        #expect(!allowed("https://other.acme.internal:8443/history/abc", baseURL: baseURL))
    }

    @Test(arguments: [
        "http://coderpad-1.firebaseio.com/abc",
        "https://localhost/abc",
        "https://127.0.0.1/abc",
        "https://169.254.169.254/latest/meta-data/",
        "https://[::1]/abc",
        "https://unrelated-project.firebaseio.com/abc",
        "https://coderpad-9.evil.firebaseio.com/abc",
        "https://coderpad-0.firebaseio.com/abc",
        "https://coderpad-09.firebaseio.com/abc",
        "https://coderpad-nine.firebaseio.com/abc",
        "https://user:password@coderpad-9.firebaseio.com/abc",
        "https://coderpad-9.firebaseio.com:444/abc",
        "https://coderpad-9.firebaseio.com/abc#fragment",
        "not a URL"
    ])
    func `unsafe and unrelated URLs are rejected`(_ url: String) {
        #expect(!allowed(url))
    }
}
