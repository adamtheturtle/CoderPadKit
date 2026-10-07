import Foundation

nonisolated extension MockScreenResponses {
    static func questionBankRoute(state: MockScreenState, method: String, route: String,
                                  query: [String: String], body: Data?) -> Result? {
        let parts = route.split(separator: "/")
        guard parts.first == "questions", parts.count <= 2 else { return nil }
        if parts.count == 1 {
            switch method {
            case "GET": return questionBankPage(state: state, query: query)
            case "POST": return saveBankQuestion(state: state, id: nil, body: body)
            default: return json(405, ["message": "Method not allowed"])
            }
        }
        guard let uuid = UUID(uuidString: String(parts[1])) else {
            return json(400, ["message": "Invalid question UUID"])
        }
        let id = uuid.uuidString.lowercased()
        switch method {
        case "GET":
            guard let question = state.bankQuestions.first(where: { $0["id"] as? String == id }) else {
                return json(404, ["message": "Question not found"])
            }
            return json(200, question)
        case "PUT": return saveBankQuestion(state: state, id: id, body: body)
        default: return json(405, ["message": "Method not allowed"])
        }
    }

    private static func saveBankQuestion(state: MockScreenState, id: String?, body: Data?) -> Result {
        guard let body, var question = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return malformedJSON()
        }
        if let id, !state.bankQuestions.contains(where: { $0["id"] as? String == id }) {
            return json(404, ["message": "Question not found"])
        }
        guard let type = question["type"] as? String,
              ["MCQ", "CODE", "TEXT", "FILE_UPLOAD", "VIDEO", "PROJECT"].contains(type) else {
            return json(400, ["message": "Unsupported writable question type"])
        }
        if id != nil, (question["project_details"] as? [String: Any])?["temporary_file_id"] != nil {
            return json(400, ["message": "Temporary project files are supported only during creation"])
        }
        let identity = id ?? UUID().uuidString.lowercased()
        let old = state.bankQuestions.first(where: { $0["id"] as? String == identity })
        if let old, old["from_coderpad_question_bank"] as? Bool == true {
            return json(403, ["message": "Question bank content cannot be modified"])
        }
        question["id"] = identity
        question["version"] = (old?["version"] as? Int ?? 0) + 1
        question["from_coderpad_question_bank"] = false
        if var project = question["project_details"] as? [String: Any] {
            project.removeValue(forKey: "temporary_file_id")
            question["project_details"] = project
        }
        state.bankQuestions.removeAll { $0["id"] as? String == identity }
        state.bankQuestions.append(question)
        let response = json(id == nil ? 201 : 200, question)
        return Result(status: response.status, body: response.body, contentType: response.contentType,
                      headers: id == nil ? ["Location": "/assessment/api/v1.1/questions/\(identity)"] : [:])
    }
}
