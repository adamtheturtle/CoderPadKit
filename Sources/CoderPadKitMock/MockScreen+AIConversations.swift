import Foundation

nonisolated extension MockScreenResponses {
    private static let conversationRoute = regex(#"^/tests/(\d+)/questions/[a-fA-F0-9-]+/ai-assist-conversations/?$"#)

    static func aiConversationRoute(state: MockScreenState, method: String, route: String) -> Result? {
        guard method == "GET", let rawID = match(route, conversationRoute), let id = Int(rawID) else { return nil }
        guard let test = state.allTests().first(where: { $0["id"] as? Int == id }),
              route.split(separator: "/").dropFirst(3).first.map(String.init)?.lowercased()
                == MockScreenFixtures.aiProjectQuestionID else {
            return json(404, ["code": "question_not_found", "message": "Project question not found"])
        }
        guard ["completed", "TO_REVIEW"].contains(test["status"] as? String ?? "")
            || test["approval_status"] as? String == "TO_REVIEW" else {
            return json(409, ["code": "test_not_finished", "message": "Test is not finished"])
        }
        return json(200, id == 5001 ? MockScreenFixtures.aiConversations() : [])
    }
}

nonisolated extension MockScreenFixtures {
    static let aiProjectQuestionID = "4143ca74-2f0e-4151-90d6-e1428739450b"

    static func aiConversations() -> [[String: Any]] {
        [["id": "conversation-1", "subject": "Project guidance", "creation_time": "2026-10-01T12:00:00.123Z",
          "messages": [
              ["id": "message-1", "role": "USER", "creation_time": "2026-10-01T12:00:00.123Z",
               "output_items": [["type": "text", "text": "Can you explain this test?", "future": ["flag": false]]]],
              ["id": "message-2", "role": "ASSISTANT", "output_items": [
                  ["type": "reasoning", "details": ["steps": ["inspect", "explain"]]],
                  ["type": "tool_call", "tool": "read_file", "metadata": ["path": "test.py", "attempt": 0]],
                  ["type": "text", "text": "The test checks the returned value."]
              ]]
          ]], ["id": "conversation-2", "messages": []]]
    }
}
