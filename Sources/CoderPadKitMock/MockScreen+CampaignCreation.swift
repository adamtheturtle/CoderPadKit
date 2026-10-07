import CoderPadKit
import Foundation

nonisolated extension MockScreenResponses {
    static func createCampaign(state: MockScreenState, body: Data?) -> Result {
        guard let body,
              let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return malformedJSON()
        }
        guard let name = params["name"] as? String, (3 ... 64).contains(name.count),
              let questions = params["questions"] as? [[String: Any]], !questions.isEmpty else {
            return json(400, ["code": "invalid_request", "message": "Invalid campaign name or questions"])
        }
        guard questions.allSatisfy(validCampaignQuestion) else {
            return json(400, ["code": "invalid_request", "message": "Invalid campaign question selection"])
        }
        let settings = params["settings"] as? [String: Any] ?? [:]
        let id = state.nextCampaignID
        state.nextCampaignID += 1
        state.createdCampaigns.append([
            "id": id, "name": name, "languages": settings["languages"] ?? [],
            "pinned": false, "archived": false
        ])
        return json(201, ["id": id])
    }

    private static func validCampaignQuestion(_ question: [String: Any]) -> Bool {
        switch question["type"] as? String {
        case "QUESTION":
            guard let id = question["question_id"] as? String else { return false }
            return UUID(uuidString: id) != nil
        case "RANDOM_QUESTION_SET":
            guard let config = question["configuration"] as? [String: Any] else { return false }
            return config["included_question_ids"] == nil || config["excluded_question_ids"] == nil
        default:
            return false
        }
    }
}
