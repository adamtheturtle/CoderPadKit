//
//  ModelsMutationsValidationTests.swift
//  CoderPadKitTests
//
//  Focused coverage for model/mutation validation issues #140–#155.
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen public init validation (#140-#142)")
struct ScreenPublicInitValidationTests {
    @Test
    func `campaign rejects a nonpositive id or blank name`() {
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenCampaign(id: 0, name: "Backend")
        }
        #expect(throws: ScreenModelValidationError.blankCampaignName) {
            _ = try ScreenCampaign(id: 1, name: "   ")
        }
    }

    @Test
    func `campaign trims a valid name`() throws {
        let campaign = try ScreenCampaign(id: 7, name: "  Backend  ")
        #expect(campaign.id == 7)
        #expect(campaign.name == "Backend")
    }

    @Test
    func `test session rejects invalid ids and timestamps`() {
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenTestSession(id: 0)
        }
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenTestSession(id: 1, sendTime: -1)
        }
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenTestSession(id: 1, startTime: .max)
        }
    }

    @Test
    func `report rejects invalid metrics`() {
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenReport(score: .nan)
        }
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenReport(points: -1)
        }
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenReport(comparativeScore: 101)
        }
        #expect(throws: ScreenModelValidationError.self) {
            _ = try ScreenReport(omittedBreakdownEntries: -5)
        }
    }
}

@Suite("Question file path validation (#143-#145)")
struct QuestionFilePathValidationTests {
    @Test(arguments: ["", "   ", "/main.py", "../secret", "C:\\main.py", "\\\\share\\file"])
    func `unsafe file paths are rejected`(_ path: String) {
        #expect(throws: QuestionMutationValidationError.self) {
            _ = try CoderPadClient.encoder.encode(
                QuestionCreate(title: "Q", fileContents: [.init(path: path, contents: "x")])
            )
        }
    }

    @Test
    func `duplicate normalized paths are rejected`() {
        #expect(throws: QuestionMutationValidationError.duplicateFilePath("main.py")) {
            _ = try CoderPadClient.encoder.encode(
                QuestionCreate(
                    title: "Q",
                    fileContents: [
                        .init(path: "main.py", contents: "A"),
                        .init(path: "main.py", contents: "B")
                    ]
                )
            )
        }
        #expect(throws: QuestionMutationValidationError.duplicateFilePath("src/main.py")) {
            _ = try CoderPadClient.encoder.encode(
                QuestionCreate(
                    title: "Q",
                    fileContents: [
                        .init(path: "src/main.py", contents: "A"),
                        .init(path: "src\\main.py", contents: "B")
                    ]
                )
            )
        }
    }

    @Test
    func `contradictory takeHome and padType are rejected`() {
        #expect(throws: QuestionMutationValidationError.contradictoryTakeHomeAndPadType) {
            _ = try CoderPadClient.encoder.encode(
                QuestionCreate(title: "Q", takeHome: true, padType: "live")
            )
        }
        _ = try? CoderPadClient.encoder.encode(
            QuestionCreate(title: "Q", takeHome: true, padType: "take-home")
        )
    }
}

@Suite("Pad mutation encoding (#146, #150, #155)")
struct PadMutationEncodingFixesTests {
    @Test
    func `nonpositive question IDs are rejected`() {
        #expect(throws: PadMutationValidationError.nonpositiveQuestionID) {
            _ = try CoderPadClient.encoder.encode(PadCreate(questionID: 0))
        }
        #expect(throws: PadMutationValidationError.nonpositiveQuestionID) {
            _ = try CoderPadClient.encoder.encode(PadUpdate(id: "DEMO", questionID: -1))
        }
    }

    @Test
    func `owner email encodes as user_email`() throws {
        let data = try CoderPadClient.encoder.encode(PadUpdate(id: "DEMO", ownerEmail: "a@b.co"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["user_email"] as? String == "a@b.co")
        #expect(root["owner_email"] == nil)
    }

    @Test
    func `unknown languages are rejected unless opted in`() {
        #expect(throws: CoderPadError.self) {
            _ = try CoderPadClient.encoder.encode(PadCreate(language: "not-a-real-lang"))
        }
        #expect(throws: CoderPadError.self) {
            _ = try CoderPadClient.encoder.encode(QuestionCreate(title: "Q", language: " "))
        }
        _ = try? CoderPadClient.encoder.encode(
            PadCreate(language: "future_lang_99", allowUnknownLanguage: true)
        )
    }
}

@Suite("Core identity decode (#148-#149, #152)")
struct CoreIdentityDecodeTests {
    @Test
    func `custom files without api ids have distinct Identifiable ids`() throws {
        let question = try CoderPadClient.decoder.decode(
            Question.self,
            from: Data(
                #"""
                {
                  "id": 1,
                  "custom_files": [
                    {"filename": "a.txt", "title": "one"},
                    {"filename": "b.txt", "title": "two"}
                  ]
                }
                """#.utf8
            )
        )
        #expect(question.customFiles[0].apiID == nil)
        #expect(question.customFiles[1].apiID == nil)
        #expect(question.customFiles[0].id != question.customFiles[1].id)
    }

    @Test
    func `question pad and environment reject invalid identities`() {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(Question.self, from: Data(#"{"id":0}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(PadEnvironment.self, from: Data(#"{"id":0}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(Pad.self, from: Data(#"{"id":""}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(Pad.self, from: Data(#"{"id":"a/b"}"#.utf8))
        }
    }

    @Test
    func `organization decodes the documented payload without an id`() throws {
        let org = try CoderPadClient.decoder.decode(
            Organization.self,
            from: Data(
                #"""
                {
                  "name": "Acme Interviewing",
                  "subdomain": "acme",
                  "default_language": "python3",
                  "user_count": 2,
                  "users": [],
                  "teams": []
                }
                """#.utf8
            )
        )
        #expect(org.id == nil)
        #expect(org.organizationName == "Acme Interviewing")
        #expect(org.organizationDefaultLanguage == "python3")
    }
}

@Suite("List sort validation (#154)")
struct ListSortValidationTests {
    @Test
    func `documented sort strings are accepted`() throws {
        #expect(try InterviewListSort.validated("created_at,asc") == "created_at,asc")
        #expect(try InterviewListSort.validated(" updated_at , DESC ") == "updated_at,desc")
        #expect(try InterviewListSort.validated(nil) == nil)
    }

    @Test
    func `unsupported sort strings are rejected before networking`() async {
        let client = CoderPadClient(apiKey: "key", session: URLSession(configuration: .ephemeral))
        await #expect(throws: CoderPadError.self) {
            _ = try await client.listPads(sort: "title,asc")
        }
        await #expect(throws: CoderPadError.self) {
            _ = try await client.listQuestions(sort: "created_at,up")
        }
        var iterator = client.listPadsIncrementally(sort: "nope").makeAsyncIterator()
        do {
            _ = try await iterator.next()
            Issue.record("Expected unsupported sort to throw before networking")
        } catch is CoderPadError {
            // Expected client-side validation failure.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
