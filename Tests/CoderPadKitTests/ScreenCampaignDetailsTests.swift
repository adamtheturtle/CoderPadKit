@testable import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

struct ScreenCampaignDetailsTests {
    @Test
    func `campaign reads preserve ordered selections and explicit settings`() async throws {
        let key = "campaign-details-\(UUID().uuidString)"
        defer { ScreenClient.resetMockState(forKey: key) }
        let client = ScreenClient.mock(key: key)
        let questionID = UUID()
        let settings = ScreenCampaignSettings(languages: [], timer: .init(mode: .global, durationMinutes: 60),
                                              copyPasteBlocked: false, aiAssistEnabled: false, enabledCodingAgents: "")
        let selections: [ScreenCampaignQuestion] = [
            .question(questionID), .randomQuestionSet(.init(domain: "backend", skills: [],
                                                            excludedQuestionIDs: []))
        ]
        let teamID = UUID()
        let created = try await client.createCampaign(.init(name: "Backend", questions: selections,
                                                            settings: settings, teamID: teamID))
        let details = try await client.getCampaign(id: created.id)
        #expect(details.name == "Backend")
        #expect(details.questions == selections)
        #expect(details.settings == settings)
        #expect(details.teamID == teamID)
        let input = ScreenCampaignCreation(name: details.name, questions: details.questions,
                                           settings: details.settings, teamID: details.teamID)
        #expect(try JSONEncoder().encode(input).isEmpty == false)
    }

    @Test
    func `omitted settings and team remain absent`() async throws {
        let client = ScreenClient.mock(key: "campaign-omitted-\(UUID().uuidString)")
        let created = try await client.createCampaign(.init(name: "Backend", questions: [.question(UUID())]))
        let details = try await client.getCampaign(id: created.id)
        #expect(details.settings == nil)
        #expect(details.teamID == nil)
        #expect(try await client.getCampaign(id: 101).questions.isEmpty == false)
    }

    @Test(arguments: [0, -1, 123_456])
    func `invalid and missing campaign IDs fail`(id: Int) async {
        await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock().getCampaign(id: id)
        }
    }

    @Test
    func `unauthorized reads keep the HTTP error`() async {
        do {
            _ = try await ScreenClient.mock(unauthorized: true).getCampaign(id: 1)
            Issue.record("Expected an authorization error")
        } catch let error as CoderPadError {
            guard case .http(401, _) = error else { Issue.record("Unexpected error: \(error)"); return }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
