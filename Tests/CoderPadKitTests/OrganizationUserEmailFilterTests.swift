//
//  OrganizationUserEmailFilterTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Organization user email filters")
struct OrganizationUserEmailFilterTests {
    @Test
    func `whitespace is trimmed and the domain is lowercased`() throws {
        let normalized = try CoderPadClient.normalizedOrganizationUserEmail("  Basil@FawltyTowers.CO.UK  ")
        #expect(normalized == "Basil@fawltytowers.co.uk")
    }

    @Test(arguments: [
        "not-an-email",
        "a@",
        "@example.com",
        "a@b",
        "two@@example.com",
        "has space@example.com",
        "null\u{0000}@example.com",
        "bidi\u{202E}@example.com"
    ])
    func `implausible addresses are rejected`(email: String) {
        #expect(throws: CoderPadError.self) {
            _ = try CoderPadClient.normalizedOrganizationUserEmail(email)
        }
    }

    @Test
    func `nil passes through unchanged`() throws {
        #expect(try CoderPadClient.normalizedOrganizationUserEmail(nil) == nil)
    }

    @Test
    func `query items carry the normalized email`() throws {
        let email = "plus+tag@example.com"
        let normalized = try #require(try CoderPadClient.normalizedOrganizationUserEmail(email))
        var comps = URLComponents(string: "https://app.coderpad.io/api/organization/users")
        comps?.queryItems = [URLQueryItem(name: "email", value: normalized)]
        let items = try #require(comps?.queryItems)
        #expect(items == [URLQueryItem(name: "email", value: "plus+tag@example.com")])
        #expect(comps?.url != nil)
        #expect(comps?.percentEncodedQuery?.contains("email=") == true)
    }
}
