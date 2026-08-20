//
//  coderpadTests+ScreenSessionValidation.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen session validation")
struct ScreenSessionValidationTests {
    private static let validOrganizationID = "4143ca74-2f0e-4151-90d6-e1428739450b"

    @Test(arguments: ["demo-org", "", "   ", "not-a-uuid", "4143ca74-2f0e-4151-90d6-e1428739450"])
    func `organization_id rejects blank and non-UUID values`(organizationID: String) {
        let json = #"{"id":1,"organization_id":"\#(organizationID)"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }

    @Test
    func `organization_id accepts a canonical UUID`() throws {
        let json = #"{"id":1,"organization_id":"\#(Self.validOrganizationID)"}"#
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))

        #expect(session.organizationID == Self.validOrganizationID)
    }

    @Test
    func `absent organization_id remains optional`() throws {
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(#"{"id":1}"#.utf8))

        #expect(session.organizationID == nil)
    }

    @Test
    func `id_test disagreeing with id is rejected`() {
        let json = #"{"id":1,"id_test":2}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }

    @Test
    func `id_test equal to id is valid`() throws {
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(#"{"id":1,"id_test":1}"#.utf8))

        #expect(session.idTest == 1)
    }

    @Test
    func `absent id_test remains optional`() throws {
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(#"{"id":1}"#.utf8))

        #expect(session.idTest == nil)
    }

    @Test
    func `an empty invitation result is rejected`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(#"{}"#.utf8))
        }
    }

    @Test
    func `an invitation result with only a blank test_url is rejected`() {
        let json = #"{"test_url":"   "}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(json.utf8))
        }
    }

    @Test
    func `an invitation result with only an id is valid`() throws {
        let result = try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(#"{"id":1}"#.utf8))

        #expect(result.id == 1)
        #expect(result.testURL == nil)
    }

    @Test
    func `an invitation result with only a test_url is valid`() throws {
        let json = #"{"test_url":"https://app.coderpad.io/screen/demo/tests/1"}"#
        let result = try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(json.utf8))

        #expect(result.id == nil)
        #expect(result.testURL == "https://app.coderpad.io/screen/demo/tests/1")
    }

    @Test
    func `an invitation result with both fields is valid`() throws {
        let json = #"{"id":1,"test_url":"https://app.coderpad.io/screen/demo/tests/1"}"#
        let result = try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(json.utf8))

        #expect(result.id == 1)
        #expect(result.testURL == "https://app.coderpad.io/screen/demo/tests/1")
    }

    @Test
    func `an invitation result rejects a nonpositive id`() {
        let json = #"{"id":0,"test_url":"https://app.coderpad.io/screen/demo/tests/1"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenInvitationResult.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: [0, -1, Int(Int32.max) + 1])
    func `campaign_id rejects values outside the positive int32 range`(campaignID: Int) {
        let json = #"{"id":1,"campaign_id":\#(campaignID)}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }

    @Test
    func `campaign_id accepts a positive int32`() throws {
        let session = try JSONDecoder().decode(
            ScreenTestSession.self, from: Data(#"{"id":1,"campaign_id":42}"#.utf8)
        )
        #expect(session.campaignID == 42)
    }

    @Test(arguments: [0, -3])
    func `id_test rejects nonpositive values even when matching would be impossible`(idTest: Int) {
        let json = #"{"id":1,"id_test":\#(idTest)}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))
        }
    }
}
