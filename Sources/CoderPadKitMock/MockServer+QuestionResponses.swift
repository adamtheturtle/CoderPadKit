//
//  MockServer+QuestionResponses.swift
//  CoderPadKitMock
//
//  Question routes for the in-process Interview API mock.
//

import Foundation

nonisolated extension MockResponses {
    static func questionRoute(
        state: MockState,
        method: String,
        path: String,
        body: Data?,
        contentType: String?
    ) -> (Int, Data)? {
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
            return ok(["status": "OK", "questions": state.allQuestions()])
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
            return malformedMultipartResponse
        }
        // Derive the id from seeds and this session's creations. Deleted ids remain
        // reserved because the live API never recycles an id it has handed out.
        let existingIDs = (MockFixtures.questions() + state.createdQuestions)
            .compactMap { $0["id"] as? Int }
        let newID = (existingIDs.max() ?? 100) + 1
        var question: [String: Any] = [
            "id": newID,
            "title": bodyDict["title"] as? String ?? "Untitled",
            "owner_email": MockFixtures.demoUserEmail,
            "language": bodyDict["language"] ?? NSNull(),
            "description": bodyDict["description"] ?? NSNull(),
            "ai_assist_custom_system_prompt": bodyDict["ai_assist_custom_system_prompt"] ?? NSNull(),
            "candidate_instructions": bodyDict["candidate_instructions"] ?? [],
            "shared": true, "used": 0, "take_home": bodyDict["take_home"] as? Bool ?? false,
            "test_cases_enabled": false, "solution": bodyDict["solution"] ?? "",
            "pad_type": bodyDict["pad_type"] as? String ?? "live", "is_draft": false,
            "contents": bodyDict["contents"] ?? NSNull(), "custom_files": [],
            "author_name": MockFixtures.demoUserName, "organization_name": MockFixtures.orgName,
            "created_at": Date.now.formatted(.iso8601),
            "updated_at": Date.now.formatted(.iso8601)
        ]
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
        guard body != nil else {
            return (400, jsonString(["status": "error"]))
        }
        // Existence before overlay writes, matching pad updates (#189).
        guard state.allQuestions().contains(where: { ($0["id"] as? Int) == idInt }) else {
            return (404, jsonString(["status": "error"]))
        }
        guard var params = questionParams(body: body, contentType: contentType) else {
            return malformedMultipartResponse
        }

        // Successful updates advance `updated_at`, matching the live API (#192).
        params["updated_at"] = Date.now.formatted(.iso8601)
        // QuestionUpdate is partial, so merge only the fields that were supplied.
        state.updatedQuestions[idInt, default: [:]]
            .merge(params) { _, new in new }
        return ok(["status": "OK"])
    }

    private static var malformedMultipartResponse: (Int, Data) {
        (400, jsonString(["status": "error", "message": "malformed multipart body"]))
    }
}
