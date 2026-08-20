//
//  coderpadTests+ScreenPaginationValidation.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen pagination validation")
struct ScreenPaginationValidationTests {
    @Test
    func `negative offsets counts and nonpositive limits are rejected`() {
        for json in [
            #"{"start":-1,"has_more_items":false}"#,
            #"{"limit":0,"has_more_items":false}"#,
            #"{"limit":-1,"has_more_items":false}"#,
            #"{"total":-1,"has_more_items":false}"#,
            #"{"next_start":-1,"has_more_items":false}"#
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
            }
        }
    }

    @Test
    func `zero offsets and total with a positive limit are valid`() throws {
        let page = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"start":0,"limit":1,"total":0,"next_start":0,"has_more_items":false}"#.utf8)
        )

        #expect(page.start == 0)
        #expect(page.limit == 1)
        #expect(page.total == 0)
        #expect(page.nextStart == 0)
    }

    @Test(arguments: [50, 1])
    func `limits up to the documented maximum are valid`(limit: Int) throws {
        let page = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"limit":\#(limit),"has_more_items":false}"#.utf8)
        )

        #expect(page.limit == limit)
    }

    @Test(arguments: [51, Int.max])
    func `limits above the documented maximum are rejected`(limit: Int) {
        let json = #"{"limit":\#(limit),"has_more_items":false}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test
    func `start greater than total is rejected`() {
        let json = #"{"start":10,"total":5,"has_more_items":false}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: [10, 5])
    func `start at or below total is valid`(total: Int) throws {
        let page = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"start":5,"total":\#(total),"has_more_items":false}"#.utf8)
        )

        #expect(page.start == 5)
        #expect(page.total == total)
    }

    @Test
    func `next_start behind start is rejected`() {
        let json = #"{"start":10,"next_start":5,"has_more_items":true}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test
    func `has more items false with a future next_start is rejected`() {
        let json = #"{"start":5,"next_start":10,"has_more_items":false}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test
    func `has more items true requires next_start to advance past start`() {
        let json = #"{"start":5,"next_start":5,"has_more_items":true}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test
    func `next_start past start with more items is valid`() throws {
        let page = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"start":5,"next_start":10,"has_more_items":true}"#.utf8)
        )

        #expect(page.start == 5)
        #expect(page.nextStart == 10)
    }

    @Test
    func `next_start equal to start with no more items is valid`() throws {
        let page = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"start":5,"next_start":5,"has_more_items":false}"#.utf8)
        )

        #expect(page.start == 5)
        #expect(page.nextStart == 5)
    }

    @Test(arguments: ["start", "limit", "total", "next_start"])
    func `present pagination integers reject strings`(field: String) {
        let json = #"{"has_more_items":false,"\#(field)":"1"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: ["start", "limit", "total", "next_start"])
    func `present pagination integers reject objects`(field: String) {
        let json = #"{"has_more_items":false,"\#(field)":{"value":1}}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
        }
    }

    @Test
    func `absent and null pagination integers remain optional`() throws {
        let absent = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(#"{"has_more_items":false}"#.utf8)
        )
        let null = try JSONDecoder().decode(
            ScreenPagination.self,
            from: Data(
                #"{"start":null,"limit":null,"total":null,"next_start":null,"has_more_items":false}"#.utf8
            )
        )

        #expect(absent.start == nil && absent.limit == nil && absent.total == nil && absent.nextStart == nil)
        #expect(null.start == nil && null.limit == nil && null.total == nil && null.nextStart == nil)
    }

    @Test
    func `has more items is required and must be boolean`() {
        for json in [
            #"{}"#,
            #"{"has_more_items":"false"}"#,
            #"{"has_more_items":0}"#,
            #"{"has_more_items":null}"#
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(ScreenPagination.self, from: Data(json.utf8))
            }
        }
    }

    @Test
    func `invalid nested pagination fails the page instead of truncating it`() {
        let json = #"{"tests":[],"pagination":{"has_more_items":"false"}}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestsPage.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: [
        #"{}"#,
        #"{"tests":null}"#,
        #"{"tests":{}}"#,
        #"{"tests":"not an array"}"#
    ])
    func `tests is a required array`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestsPage.self, from: Data(json.utf8))
        }
    }

    @Test
    func `an explicitly empty tests array remains a valid page`() throws {
        let page = try JSONDecoder().decode(ScreenTestsPage.self, from: Data(#"{"tests":[]}"#.utf8))
        #expect(page.tests.isEmpty)
        #expect(page.discardedTestCount == 0)
    }

    @Test
    func `an unreadable tail cannot publish a valid page prefix`() {
        let truncated = #"{"tests":[{"id":1,"status":"waiting"},{"id":] }"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestsPage.self, from: Data(truncated.utf8))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `a discarded value beyond the nesting limit fails instead of looping`() {
        let depth = 80
        let nested = String(repeating: "[", count: depth)
            + "null"
            + String(repeating: "]", count: depth)
        let json = "{\"tests\":[\(nested)]}"

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestsPage.self, from: Data(json.utf8))
        }
    }
}
