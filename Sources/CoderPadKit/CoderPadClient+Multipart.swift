//
//  CoderPadClient+Multipart.swift
//  CoderPadKit
//
//  Multipart request construction for question ZIP uploads.
//

import Foundation
import PaginatedRESTClient

private nonisolated struct MultipartStatusOnly: Decodable, Sendable {}

public extension CoderPadClient {
    /// Creates a multi-file question from caller-provided ZIP bytes. A ZIP cannot be
    /// combined with ``QuestionCreate/contents`` or ``QuestionCreate/fileContents``.
    func createQuestion(
        _ body: QuestionCreate,
        zipFile: QuestionZIPUpload
    ) async throws -> Question {
        let request = try multipartQuestionRequest(
            method: "POST",
            path: "/api/questions/",
            fields: try body.multipartFields(),
            hasAlternativeContentSource: body.contents != nil || body.fileContents != nil,
            zipFile: zipFile
        )
        return try await rest.perform(Question.self, request: request)
    }

    /// Modifies a question with caller-provided ZIP bytes and returns its fresh
    /// server state. A ZIP cannot be combined with ``QuestionUpdate/contents`` or
    /// ``QuestionUpdate/fileContents``.
    func updateQuestion(
        _ body: QuestionUpdate,
        zipFile: QuestionZIPUpload
    ) async throws -> Question {
        try await updateQuestionWithoutRefetch(body, zipFile: zipFile)
        return try await getQuestion(id: body.id)
    }

    /// Sends a ZIP-backed modify-question PUT without the follow-up GET.
    func updateQuestionWithoutRefetch(
        _ body: QuestionUpdate,
        zipFile: QuestionZIPUpload
    ) async throws {
        let request = try multipartQuestionRequest(
            method: "PUT",
            path: "/api/questions/\(body.id)",
            fields: try body.multipartFields(),
            hasAlternativeContentSource: body.contents != nil || body.fileContents != nil,
            zipFile: zipFile
        )
        _ = try await rest.perform(MultipartStatusOnly.self, request: request)
    }
}

extension CoderPadClient {
    func multipartQuestionRequest(
        method: String,
        path: String,
        fields: [MultipartFormField],
        hasAlternativeContentSource: Bool,
        zipFile: QuestionZIPUpload
    ) throws -> RESTRequest {
        guard !hasAlternativeContentSource else {
            throw QuestionMutationValidationError.mutuallyExclusiveContentSources
        }
        guard !apiKey.isEmpty else {
            throw CoderPadError.missingAPIKey
        }

        let multipart = MultipartFormData(
            fields: fields,
            files: [
                MultipartFormFile(
                    name: "question[zip_file]",
                    filename: zipFile.filename,
                    contentType: "application/zip",
                    data: zipFile.data
                )
            ]
        )
        return RESTRequest(
            url: baseURL.appending(path: path),
            method: method,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Accept": "application/json",
                "Content-Type": multipart.contentType
            ],
            body: multipart.body
        )
    }
}
