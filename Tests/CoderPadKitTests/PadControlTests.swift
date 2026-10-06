import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Pad access and creation settings")
struct PadControlTests {
    @Test(arguments: [nil, [], ["first@example.com", "second@example.com"]] as [[String]?], [false, true])
    func `new controls preserve explicit values and omitted lists`(emails: [String]?, enabled: Bool) throws {
        let creation = PadCreate(
            restrictInterviewerAccess: enabled, allowedInterviewerEmails: emails,
            disableCoachingTips: enabled, takeHome: enabled, takeHomeTimeLimit: 30, aiAssistEnabled: enabled
        )
        var expected: [String: Any] = [
            "restrict_interviewer_access": enabled, "disable_coaching_tips": enabled,
            "take_home": enabled, "take_home_time_limit": 30, "ai_assist_enabled": enabled
        ]
        if let emails { expected["allowed_interviewer_emails"] = emails }
        let data = try JSONEncoder().encode(creation)
        let actual = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(NSDictionary(dictionary: actual) == NSDictionary(dictionary: expected))
        let decoded = try JSONDecoder().decode(PadCreate.self, from: data)
        #expect(decoded.allowedInterviewerEmails == emails)
        #expect(decoded.restrictInterviewerAccess == enabled)
        #expect(decoded.disableCoachingTips == enabled)
        #expect(decoded.takeHome == enabled)
        #expect(decoded.takeHomeTimeLimit == 30)
        #expect(decoded.aiAssistEnabled == enabled)
    }

    @Test(arguments: [nil, [], ["first@example.com"]] as [[String]?], [false, true])
    func `updates retain ownership and exact execution strings`(emails: [String]?, enabled: Bool) throws {
        let update = PadUpdate(
            id: "pad-1", ownerEmail: "owner@example.com", isPrivate: enabled, executionEnabled: enabled,
            restrictInterviewerAccess: enabled, allowedInterviewerEmails: emails, disableCoachingTips: enabled
        )
        var expected: [String: Any] = [
            "user_email": "owner@example.com", "private": enabled,
            "execution_enabled": enabled ? "true" : "false", "restrict_interviewer_access": enabled,
            "disable_coaching_tips": enabled
        ]
        if let emails { expected["allowed_interviewer_emails"] = emails }
        let data = try JSONEncoder().encode(update)
        var actual = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(NSDictionary(dictionary: actual) == NSDictionary(dictionary: expected))
        actual["id"] = "pad-1"
        let decoded = try JSONDecoder().decode(PadUpdate.self, from: JSONSerialization.data(withJSONObject: actual))
        #expect(decoded.allowedInterviewerEmails == emails)
        #expect(decoded.restrictInterviewerAccess == enabled)
        #expect(decoded.disableCoachingTips == enabled)
        #expect(decoded.executionEnabled == enabled)
        #expect(decoded.ownerEmail == "owner@example.com")
    }

    @Test
    func `defaults omit new creation and update settings`() throws {
        let creation = try JSONEncoder().encode(PadCreate())
        let update = try JSONEncoder().encode(PadUpdate(id: "pad-1"))
        for data in [creation, update] {
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object.keys.sorted() == [])
        }
    }

    @Test
    func `mock mutations replace lists and optimistic edits retain access metadata`() async throws {
        let client = CoderPadClient.mock(key: "pad-controls-\(UUID().uuidString)")
        let created = try await client.createPad(PadCreate(
            title: "Controlled pad", restrictInterviewerAccess: true,
            allowedInterviewerEmails: ["first@example.com"], disableCoachingTips: true,
            takeHome: true, takeHomeTimeLimit: 30, aiAssistEnabled: false
        ))
        #expect(created.allowedInterviewerEmails == ["first@example.com"])
        #expect(created.restrictInterviewerAccess == true)
        #expect(created.type == "take_home")
        let renamed = created.applying(title: "Renamed pad")
        #expect(renamed.allowedInterviewerEmails == ["first@example.com"])
        let kept = try await client.updatePad(PadUpdate(id: created.id, title: "Updated"))
        #expect(kept.allowedInterviewerEmails == ["first@example.com"])
        let cleared = try await client.updatePad(PadUpdate(
            id: created.id, restrictInterviewerAccess: false, allowedInterviewerEmails: [], disableCoachingTips: false
        ))
        #expect(cleared.allowedInterviewerEmails == [])
        #expect(cleared.restrictInterviewerAccess == false)
    }

    @Test
    func `pad response access metadata distinguishes absence from empty`() throws {
        let decoder = JSONDecoder()
        let absent = try decoder.decode(Pad.self, from: Data(#"{"id":"pad-1"}"#.utf8))
        let empty = try decoder.decode(Pad.self, from: Data(#"{"id":"pad-1","allowed_interviewer_emails":[]}"#.utf8))
        #expect(absent.allowedInterviewerEmails == nil)
        #expect(empty.allowedInterviewerEmails == [])
        #expect(empty.applying(isPrivate: false).allowedInterviewerEmails == [])
    }
}
