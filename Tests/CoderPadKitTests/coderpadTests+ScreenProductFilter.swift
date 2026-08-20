//
//  coderpadTests+ScreenProductFilter.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen product filters")
struct ScreenProductFilterTests {
    @Test(arguments: ["interview", "pad", "screens", "Screening"])
    func `listTests rejects unsupported product filters before transport`(product: String) async {
        let client = ScreenClient(apiKey: "key", session: URLSession(configuration: .ephemeral))
        do {
            _ = try await client.listTests(product: product)
            Issue.record("Expected an unsupported Screen product filter to throw")
        } catch let error as CoderPadError {
            #expect(error.description.contains("product filter must be one of"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `listTests trims and lowercases valid product filters`() async throws {
        let page = try await screenClient().listTests(
            product: "  SCREEN  ",
            candidateEmail: " malformed@EXAMPLE.COM "
        )
        #expect(page.tests.map(\.id) == [1, 2])
    }
}
