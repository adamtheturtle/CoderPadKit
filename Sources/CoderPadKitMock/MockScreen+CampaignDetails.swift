import Foundation

nonisolated extension MockScreenResponses {
    static func campaignDefinition(state: MockScreenState, id: Int) -> Result {
        if let definition = state.campaignDefinitions[id] {
            return json(200, definition)
        }
        guard let campaign = state.allCampaigns().first(where: { ($0["id"] as? Int) == id }) else {
            return json(404, ["code": "NotFoundCampaignId", "message": "Campaign not found"])
        }
        return json(200, [
            "id": id, "name": campaign["name"] ?? "Assessment",
            "questions": [["type": "QUESTION", "question_id": "4143ca74-2f0e-4151-90d6-e1428739450b"]],
            "settings": ["languages": ["en"], "timer": ["mode": "GLOBAL", "duration_minutes": 60],
                         "ai_assist_enabled": false, "copy_paste_blocked": true],
            "team_id": "0558b3e3-b76c-42ea-9435-8da1adb7e232"
        ])
    }
}
