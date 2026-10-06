import Foundation

nonisolated extension MockResponses {
    static func listedQuestions(
        _ questions: [[String: Any]], query: [String: String], path: String
    ) -> (Int, Data) {
        let types = (query["pad_types[]"] ?? query["pad_type"] ?? "")
            .split(separator: ",").map(String.init)
        let allowed = path.contains("organization") ? ["live", "take_home"] : ["any", "live", "take_home"]
        guard types.allSatisfy(allowed.contains) else {
            return (400, jsonString(["status": "error", "message": "invalid question pad type"]))
        }
        let filtered = questions.filter { question in
            matchesQuestion(question, query: query, types: types)
        }
        let (sorted, error) = MockList.sorted(filtered, query: query, questionFields: true)
        if let error { return error }
        return MockList.page(sorted ?? [], query: query, path: path, collectionKey: "questions")
    }

    private static func matchesQuestion(
        _ question: [String: Any], query: [String: String], types: [String]
    ) -> Bool {
        let rawType = question["pad_type"] as? String ?? ""
        let type = rawType == "any" ? "any" : ((question["take_home"] as? Bool == true) ? "take_home" : "live")
        if !types.isEmpty, type != "any", !types.contains(type) { return false }
        if let language = query["language"], question["language"] as? String != language { return false }
        if let text = query["text"] {
            let searchable = ["title", "description", "contents"].compactMap { question[$0] as? String }
            if !searchable.contains(where: { $0.localizedCaseInsensitiveContains(text) }) { return false }
        }
        return true
    }
}
