//
//  coderpadTests+ScreenDates.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen epoch timestamps")
struct ScreenEpochTimestampTests {
    @Test(arguments: [Int.min, -1, 0, 946_684_799_999, 4_102_444_800_001, Int.max])
    func `impossible timestamps do not become dates`(milliseconds: Int) {
        #expect(ScreenEpochMilliseconds.date(from: milliseconds) == nil)
    }

    @Test
    func `session decoding rejects an impossible timestamp`() {
        let json = #"{"id":1,"status":"waiting","send_time":9223372036854775807}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }

    @Test
    func `valid boundary timestamps convert`() {
        #expect(ScreenEpochMilliseconds.date(from: ScreenEpochMilliseconds.earliest) != nil)
        #expect(ScreenEpochMilliseconds.date(from: ScreenEpochMilliseconds.latest) != nil)
    }

    @Test
    func `consistent chronology decodes`() throws {
        let json = #"""
        {
          "id": 1,
          "send_time": 1700000000000,
          "start_time": 1700000100000,
          "end_time": 1700000200000,
          "last_activity_time": 1700000150000
        }
        """#
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        #expect(session.startTime == 1_700_000_100_000)
        #expect(session.endTime == 1_700_000_200_000)
    }

    @Test(arguments: [
        #"{"id":1,"send_time":1700000100000,"start_time":1700000000000}"#,
        #"{"id":1,"start_time":1700000200000,"end_time":1700000100000}"#,
        #"{"id":1,"send_time":1700000200000,"end_time":1700000100000}"#,
        #"{"id":1,"send_time":1700000100000,"last_activity_time":1700000000000}"#,
        #"{"id":1,"end_time":1700000100000,"last_activity_time":1700000200000}"#
    ])
    func `impossible chronology is rejected`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }
}
