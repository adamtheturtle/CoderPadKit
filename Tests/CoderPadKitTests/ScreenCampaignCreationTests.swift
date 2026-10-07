@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen campaign creation")
struct ScreenCampaignCreationTests {
    private let questionID = UUID(uuidString: "4143ca74-2f0e-4151-90d6-e1428739450b")!

    @Test
    func `minimal request omits team defaults and retains question order`() throws {
        let request = ScreenCampaignCreation(name: "Backend", questions: [
            .question(questionID), .randomQuestionSet(ScreenRandomQuestionConfiguration())
        ])
        let actual = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(request))
        #expect(actual == .object([
            "name": .string("Backend"),
            "questions": .array([
                .object(["type": .string("QUESTION"), "question_id": .string(questionID.uuidString)]),
                .object(["type": .string("RANDOM_QUESTION_SET"), "configuration": .object([:])])
            ])
        ]))
    }

    @Test
    func `all settings encode with false zero and empty values intact`() throws {
        let configuration = ScreenRandomQuestionConfiguration(
            domain: "Backend", skills: ["SQL"], questionType: .code,
            targetDurationMinutes: 10, targetExperienceLevel: .senior, includedQuestionIDs: [questionID]
        )
        let settings = ScreenCampaignSettings(
            languages: [], timer: ScreenCampaignTimer(mode: .global, durationMinutes: 10),
            invitationExpirationDays: 0,
            accessPeriod: ScreenCampaignAccessPeriod(minStartTime: "2026-10-01T00:00:00Z",
                                                    maxEndTime: "2026-10-31T00:00:00Z"),
            sendCandidateSimplifiedReport: false, copyPasteBlocked: false,
            followUpQuestions: ScreenCampaignFollowUpQuestions(enabled: false, answerFormat: .video),
            webcamProctoring: ScreenCampaignWebcamProctoring(enabled: false, aiAnalysisEnabled: false),
            fullScreenRequired: false, aiAssistEnabled: false, enabledCodingAgents: ""
        )
        let request = ScreenCampaignCreation(name: "Backend", questions: [.randomQuestionSet(configuration)],
                                             settings: settings, teamID: questionID)
        let actual = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(request))
        let expected = """
        {"name":"Backend","team_id":"\(questionID.uuidString)","questions":[{
          "type":"RANDOM_QUESTION_SET","configuration":{"domain":"Backend","skills":["SQL"],
          "question_type":"CODE","target_duration_minutes":10,"target_experience_level":"SENIOR",
          "included_question_ids":["\(questionID.uuidString)"]}}],"settings":{
          "languages":[],"timer":{"mode":"GLOBAL","duration_minutes":10},"invitation_expiration_days":0,
          "access_period":{"min_start_time":"2026-10-01T00:00:00Z","max_end_time":"2026-10-31T00:00:00Z"},
          "send_candidate_simplified_report":false,"copy_paste_blocked":false,
          "follow_up_questions":{"enabled":false,"answer_format":"VIDEO"},
          "webcam_proctoring":{"enabled":false,"ai_analysis_enabled":false},
          "full_screen_required":false,"ai_assist_enabled":false,"enabled_coding_agents":""}}
        """
        #expect(actual == (try JSONDecoder().decode(JSONValue.self, from: Data(expected.utf8))))
    }

    @Test
    func `included and excluded IDs cannot be combined`() {
        let request = ScreenCampaignCreation(name: "Backend", questions: [
            .randomQuestionSet(ScreenRandomQuestionConfiguration(includedQuestionIDs: [], excludedQuestionIDs: []))
        ])
        #expect(throws: CoderPadError.self) { try JSONEncoder().encode(request) }
    }

    @Test
    func `created campaigns can be listed and invited to in isolated demo stores`() async throws {
        let key = "campaign-create-\(UUID().uuidString)"
        defer { ScreenClient.resetMockState(forKey: key) }
        let client = ScreenClient.mock(key: key)
        let result = try await client.createCampaign(ScreenCampaignCreation(
            name: "New assessment", questions: [.question(questionID)],
            settings: ScreenCampaignSettings(languages: ["python"])
        ))
        #expect(result.id == 9000)
        let campaigns = try await client.listCampaigns()
        #expect(campaigns.last?.name == "New assessment")
        #expect(campaigns.last?.languages == ["python"])
        let invitation = try await client.sendInvitation(campaignID: result.id, ScreenInvitation())
        #expect(invitation.id == 9000)
        #expect(try await ScreenClient.mock(key: "other-\(UUID().uuidString)").listCampaigns().count
            == MockScreenFixtures.campaigns().count)
    }

    @Test(arguments: ["ab", String(repeating: "x", count: 65)])
    func `invalid names fail before creating campaigns`(name: String) async throws {
        let client = ScreenClient.mock(key: "invalid-campaign-\(UUID().uuidString)")
        await #expect(throws: CoderPadError.self) {
            try await client.createCampaign(ScreenCampaignCreation(name: name, questions: [.question(questionID)]))
        }
    }

    @Test
    func `empty question lists fail and unauthorized errors retain the public contract`() async throws {
        await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock().createCampaign(ScreenCampaignCreation(name: "Backend", questions: []))
        }
        do {
            _ = try await ScreenClient.mock(unauthorized: true).createCampaign(
                ScreenCampaignCreation(name: "Backend", questions: [.question(questionID)])
            )
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case .http(401, _) = error else { Issue.record("Unexpected error: \(error)")
                return }
        }
    }
}
