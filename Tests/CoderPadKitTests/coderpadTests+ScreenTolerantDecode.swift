//
//  coderpadTests+ScreenTolerantDecode.swift
//  coderpadTests
//
//  One malformed nested element (question, tag, report, warning, or campaign
//  language) must not hide an otherwise valid Screen record (#215, #216,
//  #217, #218, #219).
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen tolerant nested element decoding")
struct ScreenTolerantDecodeTests {
    // MARK: - #215 questions

    @Test
    func `a malformed nested question is dropped without failing the session`() throws {
        let json = #"""
        {"id":1,"questions":[{"id":10},{"id":"broken"},{"id":11},{"id":-1}]}
        """#

        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))

        #expect(session.questions.map(\.id) == [10, 11])
        #expect(session.omittedQuestionCount == 2)
    }

    @Test
    func `an explicitly empty questions array remains valid with no omissions`() throws {
        let session = try JSONDecoder().decode(
            ScreenTestSession.self, from: Data(#"{"id":1,"questions":[]}"#.utf8)
        )

        #expect(session.questions.isEmpty)
        #expect(session.omittedQuestionCount == 0)
    }

    @Test
    func `questions of the wrong top-level shape still fail the session`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ScreenTestSession.self, from: Data(#"{"id":1,"questions":"not an array"}"#.utf8)
            )
        }
    }

    // MARK: - #216 tags

    @Test
    func `a malformed tag element is dropped without failing the session`() throws {
        let json = #"{"id":1,"tags":["priority",5,null,{"x":1},"senior"]}"#

        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))

        #expect(session.tags == ["priority", "senior"])
        #expect(session.omittedTagCount == 3)
    }

    @Test
    func `tags of the wrong top-level shape still fail the session`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ScreenTestSession.self, from: Data(#"{"id":1,"tags":"not an array"}"#.utf8)
            )
        }
    }

    // MARK: - #217 report

    @Test
    func `an invalid optional report is omitted rather than failing the session`() throws {
        // score is out of the valid 0-100 percentage range, which fails ScreenReport
        // decoding on its own; the session identity (id, status) is otherwise valid.
        let json = #"{"id":1,"status":"completed","report":{"score":150}}"#

        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(json.utf8))

        #expect(session.id == 1)
        #expect(session.status == "completed")
        #expect(session.report == nil)
        #expect(session.reportOmitted)
    }

    @Test
    func `an absent report is not marked as omitted`() throws {
        let session = try JSONDecoder().decode(ScreenTestSession.self, from: Data(#"{"id":1}"#.utf8))

        #expect(session.report == nil)
        #expect(!session.reportOmitted)
    }

    @Test
    func `an explicit null report is not marked as omitted`() throws {
        let session = try JSONDecoder().decode(
            ScreenTestSession.self, from: Data(#"{"id":1,"report":null}"#.utf8)
        )

        #expect(session.report == nil)
        #expect(!session.reportOmitted)
    }

    @Test
    func `a valid report decodes normally and is not marked as omitted`() throws {
        let session = try JSONDecoder().decode(
            ScreenTestSession.self, from: Data(#"{"id":1,"report":{"score":80}}"#.utf8)
        )

        #expect(session.report?.score == 80)
        #expect(!session.reportOmitted)
    }

    // MARK: - #218 warnings

    @Test
    func `a malformed warning element is dropped without failing the report`() throws {
        let json = #"{"warnings":["ok",5,null,{"x":1},"another"]}"#

        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.warnings == ["ok", "another"])
        #expect(report.omittedWarningCount == 3)
    }

    @Test
    func `warnings of the wrong top-level shape still fail the report`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(#"{"warnings":"not an array"}"#.utf8))
        }
    }

    // MARK: - #219 campaign languages

    @Test
    func `a malformed campaign language element is dropped without failing the campaign`() throws {
        let json = #"{"id":1,"name":"Backend","languages":["java",5,null,"python"]}"#

        let campaign = try JSONDecoder().decode(ScreenCampaign.self, from: Data(json.utf8))

        #expect(campaign.languages == ["java", "python"])
        #expect(campaign.omittedLanguageCount == 2)
    }

    @Test
    func `campaign languages of the wrong top-level shape still fail the campaign`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ScreenCampaign.self, from: Data(#"{"id":1,"name":"Backend","languages":"not an array"}"#.utf8)
            )
        }
    }
}
