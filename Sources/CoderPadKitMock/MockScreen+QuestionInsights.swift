import Foundation

nonisolated extension MockScreenResponses {
    private static let insightsRoute = regex(#"^/questions/([a-fA-F0-9-]+)/insights/?$"#)

    static func questionInsightsRoute(method: String, route: String, query: [String: String]) -> Result? {
        guard method == "GET", let id = match(route, insightsRoute) else { return nil }
        guard UUID(uuidString: id) != nil else {
            return json(400, ["code": "invalid_question_id", "message": "Invalid question ID"])
        }
        guard query["programming_language"] != "invalid" else {
            return json(400, ["code": "invalid_language", "message": "Invalid programming language"])
        }
        switch id.lowercased() {
        case MockScreenFixtures.insightsQuestionID:
            return json(200, MockScreenFixtures.questionInsights(language: query["programming_language"]))
        case MockScreenFixtures.emptyInsightsQuestionID:
            return json(200, ["id": id, "frequent_answers": [], "testcases_success": [],
                              "scores_distribution": ["distribution": [], "total_candidates": 0]])
        default:
            return json(404, ["code": "question_not_found", "message": "Question not found"])
        }
    }
}

nonisolated extension MockScreenFixtures {
    static let insightsQuestionID = "4143ca74-2f0e-4151-90d6-e1428739450b"
    static let emptyInsightsQuestionID = "4143ca74-2f0e-4151-90d6-e1428739450c"

    static func questionInsights(language: String?) -> [String: Any] {
        [
            "id": insightsQuestionID,
            "usage": ["view_count": 12, "last_view_time": "2026-10-01T00:00:00Z",
                      "average_answer_duration_seconds": 0, "timeout_rate": 0,
                      "average_score": language == "C++" ? 0.5 : 0],
            "frequent_answers": [["label": "A", "count": 0, "percentage": 0, "correct": false]],
            "testcases_success": [["label": "Case 1", "count": 2, "percentage": 1, "correct": true]],
            "scores_distribution": ["distribution": [
                ["score_range": "ZERO_SCORE", "candidate_count": 0],
                ["score_range": "PARTIAL_SCORE", "candidate_count": 1],
                ["score_range": "FULL_SCORE", "candidate_count": 2]
            ], "total_candidates": 3]
        ]
    }
}
