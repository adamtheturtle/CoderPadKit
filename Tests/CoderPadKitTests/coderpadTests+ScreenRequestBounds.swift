//
//  coderpadTests+ScreenRequestBounds.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen request bounds")
struct ScreenRequestBoundsTests {
    @Test
    func `decoded primary IDs reject values above int32 max`() {
        let over = Int(Int32.max) + 1
        let json = #"{"id":\#(over),"status":"waiting"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }

    @Test
    func `request IDs reject values above int32 max`() {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.requirePositiveID(Int(Int32.max) + 1, kind: "campaign")
        }
    }

    @Test
    func `time filters reject timestamps outside the response range`() {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.validateTimeRange(from: ScreenEpochMilliseconds.earliest - 1, until: nil)
        }
        #expect(throws: CoderPadError.self) {
            try ScreenClient.validateTimeRange(from: nil, until: ScreenEpochMilliseconds.latest + 1)
        }
    }

    @Test
    func `time filters accept the shared response range`() throws {
        try ScreenClient.validateTimeRange(
            from: ScreenEpochMilliseconds.earliest,
            until: ScreenEpochMilliseconds.latest
        )
    }

    @Test
    func `pagination start rejects overflow-prone offsets`() {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.requirePaginationStart(Int.max)
        }
        #expect(throws: CoderPadError.self) {
            try ScreenClient.requirePaginationStart(Int.max - ScreenClient.maximumPageSize + 1)
        }
    }

    @Test
    func `pagination start accepts the largest safe offset`() throws {
        try ScreenClient.requirePaginationStart(Int.max - ScreenClient.maximumPageSize)
    }
}
