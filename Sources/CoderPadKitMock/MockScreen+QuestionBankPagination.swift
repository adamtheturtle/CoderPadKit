import Foundation

nonisolated extension MockScreenResponses {
    static func questionBankPage(state: MockScreenState, query: [String: String]) -> Result {
        guard let start = Int(query["start"] ?? "0"), start >= 0,
              let limit = Int(query["limit"] ?? "50"), (1 ... 50).contains(limit) else {
            return json(400, ["message": "Invalid question pagination"])
        }
        let questions = state.bankQuestions.filter { question in
            questionMatchesFilters(question, query: query)
        }.sorted { lhs, rhs in
            let requested = query["sort"] ?? "id"
            let field = requested == "programming_language" ? "programming_language_id" : requested
            let comparison = questionSortComparison(lhs[field], rhs[field])
            return query["order"] == "desc" ? comparison == .orderedDescending : comparison == .orderedAscending
        }
        let page = Array(questions.dropFirst(start).prefix(limit))
        let next = start + page.count
        let more = next < questions.count
        return json(200, ["questions": page, "pagination": ["start": start, "limit": limit,
            "total": questions.count, "has_more_items": more, "next_start": more ? next : start]])
    }

    private static func questionSortComparison(_ lhs: Any?, _ rhs: Any?) -> ComparisonResult {
        if let first = lhs as? Bool, let second = rhs as? Bool {
            return first == second ? .orderedSame : first ? .orderedDescending : .orderedAscending
        }
        if let first = lhs as? Int, let second = rhs as? Int {
            return first < second ? .orderedAscending : first > second ? .orderedDescending : .orderedSame
        }
        let first = (lhs as? String) ?? ((lhs as? [String: String])?["en"]) ?? ""
        let second = (rhs as? String) ?? ((rhs as? [String: String])?["en"]) ?? ""
        return first.compare(second, options: .literal)
    }

    private static func questionMatchesFilters(_ question: [String: Any], query: [String: String]) -> Bool {
        for key in ["type", "difficulty", "domain", "skill", "product"] {
            if let value = query[key], question[key] as? String != value { return false }
        }
        if let language = query["programming_language"], question["programming_language_id"] as? String != language {
            return false
        }
        if let value = query["from_coderpad_question_bank"],
           question["from_coderpad_question_bank"] as? Bool != (value == "true") { return false }
        if let minimum = query["duration_seconds_min"].flatMap(Int.init),
           (question["duration_seconds"] as? Int ?? 0) < minimum { return false }
        if let maximum = query["duration_seconds_max"].flatMap(Int.init),
           (question["duration_seconds"] as? Int ?? 0) > maximum { return false }
        return true
    }
}
