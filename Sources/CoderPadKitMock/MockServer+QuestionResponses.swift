//
//  MockServer+QuestionResponses.swift
//  CoderPadKitMock
//
//  Question routes for the in-process Interview API mock.
//

import Foundation

nonisolated extension MockResponses {
    // Query is required for list sorting/pagination alongside the multipart body pair.
    // swiftlint:disable:next cyclomatic_complexity function_parameter_count
    static func questionRoute(
        state: MockState,
        method: String,
        path: String,
        query: [String: String],
        body: Data?,
        contentType: String?
    ) -> (Int, Data)? {
        if let response = questionVariantRoute(state: state, method: method, path: path, body: body) {
            return response
        }
        if method == "POST", path == "/api/questions/" || path == "/api/questions" {
            return createQuestion(state: state, body: body, contentType: contentType)
        }

        if method == "PUT", let id = match(path, pattern: #"^/api/questions/(\d+)/?$"#) {
            guard let idInt = Int(id) else { return invalidQuestionIDResponse }
            return modifyQuestion(
                state: state,
                idInt: idInt,
                body: body,
                contentType: contentType
            )
        }

        if method == "DELETE", let id = match(path, pattern: #"^/api/questions/(\d+)/?$"#) {
            guard let idInt = Int(id) else { return invalidQuestionIDResponse }
            guard state.allQuestions().contains(where: { ($0["id"] as? Int) == idInt }) else {
                return (404, jsonString(["status": "error"]))
            }
            state.deletedQuestionIDs.insert(idInt)
            return (200, jsonString(["status": "OK"]))
        }

        if method == "GET", let id = match(path, pattern: #"^/api/questions/(\d+)/?$"#) {
            guard let idInt = Int(id) else { return invalidQuestionIDResponse }
            if var question = state.allQuestions().first(where: { ($0["id"] as? Int) == idInt }) {
                // Mirror the live API: the question's fields are returned flat.
                question["status"] = "OK"
                return ok(question)
            }
            return (404, jsonString(["status": "error"]))
        }

        if method == "GET", path == "/api/questions/" || path == "/api/questions" {
            return listedQuestions(state.allQuestions(), query: query, path: "/api/questions/")
        }

        return nil
    }

    private static var invalidQuestionIDResponse: (Int, Data) {
        (400, jsonString(["status": "error", "message": "invalid question ID"]))
    }

    private static func createQuestion(
        state: MockState,
        body: Data?,
        contentType: String?
    ) -> (Int, Data) {
        guard let bodyDict = questionParams(body: body, contentType: contentType) else {
            return questionParamsError(contentType: contentType)
        }
        if let databaseID = bodyDict["custom_database_id"] as? Int, databaseID != 501 {
            return invalidCustomDatabaseResponse
        }
        // Derive the id from seeds and this session's creations. Deleted ids remain
        // reserved because the live API never recycles an id it has handed out.
        let existingIDs = Set(
            (MockFixtures.questions() + state.createdQuestions).compactMap { $0["id"] as? Int }
        )
        let reserved = existingIDs.union(state.deletedQuestionIDs)
        var newID = (existingIDs.max() ?? 100) + 1
        while reserved.contains(newID) { newID += 1 }
        var question: [String: Any] = [
            "id": newID,
            "title": bodyDict["title"] as? String ?? "Untitled",
            "owner_email": MockFixtures.demoUserEmail,
            "language": bodyDict["language"] ?? NSNull(),
            "description": bodyDict["description"] ?? NSNull(),
            "ai_assist_custom_system_prompt": bodyDict["ai_assist_custom_system_prompt"] ?? NSNull(),
            "candidate_instructions": bodyDict["candidate_instructions"] ?? [],
            "shared": bodyDict["shared"] as? Bool ?? true, "used": 0,
            "take_home": bodyDict["take_home"] as? Bool ?? false,
            "test_cases_enabled": false, "solution": bodyDict["solution"] ?? "",
            "pad_type": bodyDict["pad_type"] as? String ?? "live", "is_draft": false,
            "contents": bodyDict["contents"] ?? NSNull(), "custom_files": [],
            "author_name": MockFixtures.demoUserName, "organization_name": MockFixtures.orgName,
            "created_at": Date.now.formatted(.iso8601),
            "updated_at": Date.now.formatted(.iso8601)
        ]
        if bodyDict["custom_database_id"] as? Int == 501 {
            question["custom_database"] = MockFixtures.customDatabase()
        }
        if let error = applyParentFiles(bodyDict, to: &question, creating: true) { return error }
        state.createdQuestions.append(question)
        // Mirror the live API: the question's fields are returned flat at the top level.
        question["status"] = "OK"
        return ok(question)
    }

    private static func modifyQuestion(
        state: MockState,
        idInt: Int,
        body: Data?,
        contentType: String?
    ) -> (Int, Data) {
        // Existence before overlay writes, matching pad updates (#189 / #125).
        guard state.allQuestions().contains(where: { ($0["id"] as? Int) == idInt }) else {
            return (404, jsonString(["status": "error"]))
        }
        guard var params = questionParams(body: body, contentType: contentType) else {
            return questionParamsError(contentType: contentType)
        }

        if params["shared"] != nil,
           let question = state.allQuestions().first(where: { ($0["id"] as? Int) == idInt }),
           question["owner_email"] as? String != MockFixtures.demoUserEmail {
            return (403, jsonString(["status": "ERROR", "message": "Only the author can change sharing"]))
        }
        if let databaseID = params["custom_database_id"] as? Int {
            guard databaseID == 501 else { return invalidCustomDatabaseResponse }
            params["custom_database"] = MockFixtures.customDatabase()
            params.removeValue(forKey: "custom_database_id")
        }
        if let current = state.allQuestions().first(where: { ($0["id"] as? Int) == idInt }) {
            var updated = current
            if let error = applyParentFiles(params, to: &updated, creating: false) { return error }
            if params["file_contents"] != nil { params["file_contents"] = updated["file_contents"] }
        }
        // Successful updates advance `updated_at`, matching the live API (#192).
        params["updated_at"] = Date.now.formatted(.iso8601)
        // QuestionUpdate is partial, so merge only the fields that were supplied.
        state.updatedQuestions[idInt, default: [:]]
            .merge(params) { _, new in new }
        return ok(["status": "OK"])
    }

    private static func questionParamsError(contentType: String?) -> (Int, Data) {
        if contentType?.hasPrefix("multipart/form-data;") == true {
            return malformedMultipartResponse
        }
        return invalidJSONBodyResponse
    }

    private static var invalidCustomDatabaseResponse: (Int, Data) {
        (400, jsonString(["status": "ERROR", "message": "Custom database not found"]))
    }

    private static var malformedMultipartResponse: (Int, Data) {
        (400, jsonString(["status": "error", "message": "malformed multipart body"]))
    }
}
