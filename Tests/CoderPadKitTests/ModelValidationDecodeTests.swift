//
//  ModelValidationDecodeTests.swift
//  CoderPadKitTests
//
//  Focused decode validation and element-level tolerance for issues #176–#185.
//

import CoderPadKit
import Foundation
import Testing

@Suite("Model validation decode (#176-#185)")
struct ModelValidationDecodeTests {
    // MARK: - #176 QuestionCustomDatabase IDs

    @Test
    func `custom database rejects a nonpositive id`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                QuestionCustomDatabase.self,
                from: Data(#"{"id":0}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                QuestionCustomDatabase.self,
                from: Data(#"{"id":-3}"#.utf8)
            )
        }
    }

    @Test
    func `question omits a custom database with a nonpositive id`() throws {
        let question = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"custom_database":{"id":0,"title":"Orders"}}"#.utf8)
        )
        #expect(question.customDatabase == nil)
    }

    // MARK: - #177 Question.used and publicTakeHomeSettingID

    @Test
    func `question omits a negative used count`() throws {
        let question = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"used":-1}"#.utf8)
        )
        #expect(question.used == nil)
    }

    @Test
    func `question keeps a zero used count`() throws {
        let question = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"used":0}"#.utf8)
        )
        #expect(question.used == 0)
    }

    @Test
    func `question omits a nonpositive take-home setting id`() throws {
        let zero = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"public_take_home_setting_id":0}"#.utf8)
        )
        let negative = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"public_take_home_setting_id":-4}"#.utf8)
        )
        #expect(zero.publicTakeHomeSettingID == nil)
        #expect(negative.publicTakeHomeSettingID == nil)
    }

    @Test
    func `question keeps a positive take-home setting id`() throws {
        let question = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(#"{"id":1,"public_take_home_setting_id":9}"#.utf8)
        )
        #expect(question.publicTakeHomeSettingID == 9)
    }

    // MARK: - #178 Organization and Quota counts

    @Test
    func `organization rejects a negative user count`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Organization.self,
                from: Data(
                    #"""
                    {
                      "id": 1,
                      "organization_name": "Acme",
                      "user_count": -1,
                      "users": [],
                      "teams": []
                    }
                    """#.utf8
                )
            )
        }
    }

    @Test
    func `organization user rejects negative pads created`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                OrganizationUser.self,
                from: Data(#"{"email":"a@b.co","pads_created":-2}"#.utf8)
            )
        }
    }

    @Test
    func `organization stats rejects negative pads created`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                OrganizationStats.self,
                from: Data(#"{"pads_created":-1,"users":[]}"#.utf8)
            )
        }
    }

    @Test
    func `quota rejects negative usage remaining or limit`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Quota.self, from: Data(#"{"pads_used":-1}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Quota.self, from: Data(#"{"pads_remaining":-1}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Quota.self, from: Data(#"{"billing_cycle_pad_limit":-5}"#.utf8)
            )
        }
    }

    @Test
    func `quota rejects remaining above a finite limit`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Quota.self,
                from: Data(#"{"pads_remaining":10,"billing_cycle_pad_limit":5}"#.utf8)
            )
        }
    }

    @Test
    func `quota accepts remaining equal to the limit`() throws {
        let quota = try CoderPadClient.decoder.decode(
            Quota.self,
            from: Data(#"{"pads_remaining":5,"billing_cycle_pad_limit":5}"#.utf8)
        )
        #expect(quota.padsRemaining == 5)
        #expect(quota.billingCyclePadLimit == 5)
    }

    // MARK: - #179 PadInterviewerNotification id

    @Test
    func `interviewer notification rejects a nonpositive id`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                PadInterviewerNotification.self,
                from: Data(#"{"id":0}"#.utf8)
            )
        }
    }

    // MARK: - #180 Pad participants

    @Test
    func `pad keeps valid participants when a sibling element is malformed`() throws {
        let json = Data(
            #"{"id":"P1","participants":["Ada",null,5,{"x":1},"Grace"]}"#.utf8
        )
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: json)
        #expect(pad.participants == ["Ada", "Grace"])
        #expect(pad.omittedParticipantCount == 3)
        #expect(pad.omittedParticipantsDiagnostic == "Ignored 3 malformed participants.")
    }

    // MARK: - #181 Pad interviewer notifications

    @Test
    func `pad keeps valid notifications when a sibling is malformed`() throws {
        let json = Data(
            #"""
            {
              "id": "P2",
              "pad_interviewer_notifications": [
                {"id": 1, "title": "ok"},
                {"id": 0, "title": "bad id"},
                "not-an-object",
                {"id": 2, "title": "also ok"}
              ]
            }
            """#.utf8
        )
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: json)
        #expect(pad.padInterviewerNotifications.map(\.id) == [1, 2])
        #expect(pad.omittedInterviewerNotificationCount == 2)
        #expect(
            pad.omittedNotificationsDiagnostic
                == "Ignored 2 malformed interviewer notifications."
        )
    }

    // MARK: - #182 pad_environment_ids

    @Test
    func `pad keeps valid positive environment ids when siblings are malformed`() throws {
        let json = Data(
            #"{"id":"P3","pad_environment_ids":[1,null,"x",0,-2,3]}"#.utf8
        )
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: json)
        #expect(pad.padEnvironmentIDs == [1, 3])
        #expect(pad.omittedPadEnvironmentIDCount == 4)
        #expect(pad.omittedPadEnvironmentIDsDiagnostic == "Ignored 4 malformed pad environment ids.")
    }

    // MARK: - #183 Question.customFiles

    @Test
    func `question keeps valid custom files when a sibling is malformed`() throws {
        let json = Data(
            #"""
            {
              "id": 1,
              "custom_files": [
                {"id":"a","title":"one"},
                "nope",
                {"id":"b","title":"two"}
              ]
            }
            """#.utf8
        )
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)
        #expect(question.customFiles.map(\.id) == ["a", "b"])
        #expect(question.omittedCustomFileCount == 1)
        #expect(question.omittedCustomFilesDiagnostic == "Ignored 1 malformed custom file.")
    }

    // MARK: - #184 Question.testCases

    @Test
    func `question keeps valid test cases and drops nonpositive ids`() throws {
        let json = Data(
            #"""
            {
              "id": 1,
              "test_cases": [
                {"id": 10, "return_value": "1"},
                {"id": 0, "return_value": "bad"},
                "broken",
                {"id": 11, "return_value": "2"}
              ]
            }
            """#.utf8
        )
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)
        #expect(question.testCases.map(\.id) == [10, 11])
        #expect(question.omittedTestCaseCount == 2)
        #expect(question.omittedTestCasesDiagnostic == "Ignored 2 malformed test cases.")
    }

    // MARK: - #185 Question.candidateInstructions

    @Test
    func `question keeps valid candidate instructions when a sibling is malformed`() throws {
        let json = Data(
            #"""
            {
              "id": 1,
              "candidate_instructions": [
                {"instructions": "Read carefully", "default_visible": true},
                42,
                {"instructions": "Then code", "default_visible": false}
              ]
            }
            """#.utf8
        )
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)
        #expect(question.candidateInstructions.map(\.instructions) == ["Read carefully", "Then code"])
        #expect(question.omittedCandidateInstructionCount == 1)
        #expect(
            question.omittedCandidateInstructionsDiagnostic
                == "Ignored 1 malformed candidate instruction."
        )
    }
}
