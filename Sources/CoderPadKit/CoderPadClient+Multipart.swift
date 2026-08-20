//
//  CoderPadClient+Multipart.swift
//  CoderPadKit
//
//  Multipart request construction for question ZIP uploads.
//

import Foundation
import PaginatedRESTClient

private nonisolated struct MultipartStatusOnly: Decodable, Sendable {}

nonisolated struct StagedMultipartRequest: Sendable {
    let request: RESTRequest
    let multipart: MultipartFormData

    func remove() {
        multipart.remove()
    }
}

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
        defer { request.remove() }
        return try await rest.perform(Question.self, request: request.request)
    }

    /// Modifies a question with caller-provided ZIP bytes and returns its fresh
    /// server state. A ZIP cannot be combined with ``QuestionUpdate/contents`` or
    /// ``QuestionUpdate/fileContents``.
    func updateQuestion(
        _ body: QuestionUpdate,
        zipFile: QuestionZIPUpload
    ) async throws -> Question {
        try Self.validatePositiveResourceID(body.id, kind: "question")
        try await updateQuestionWithoutRefetch(body, zipFile: zipFile)
        do {
            return try await getQuestion(id: body.id)
        } catch {
            throw CoderPadMutationRefreshError(target: .question(id: body.id), underlying: error)
        }
    }

    /// Sends a ZIP-backed modify-question PUT without the follow-up GET.
    func updateQuestionWithoutRefetch(
        _ body: QuestionUpdate,
        zipFile: QuestionZIPUpload
    ) async throws {
        try Self.validatePositiveResourceID(body.id, kind: "question")
        let request = try multipartQuestionRequest(
            method: "PUT",
            path: "/api/questions/\(body.id)",
            fields: try body.multipartFields(),
            hasAlternativeContentSource: body.contents != nil || body.fileContents != nil,
            zipFile: zipFile
        )
        defer { request.remove() }
        _ = try await rest.perform(MultipartStatusOnly.self, request: request.request)
    }
}

extension CoderPadClient {
    func multipartQuestionRequest(
        method: String,
        path: String,
        fields: [MultipartFormField],
        hasAlternativeContentSource: Bool,
        zipFile: QuestionZIPUpload
    ) throws -> StagedMultipartRequest {
        guard !hasAlternativeContentSource else {
            throw QuestionMutationValidationError.mutuallyExclusiveContentSources
        }
        guard !apiKey.isEmpty else {
            throw CoderPadError.missingAPIKey
        }
        try zipFile.validate()

        let multipart = try MultipartFormData(
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
        return StagedMultipartRequest(
            request: RESTRequest(
                url: baseURL.appending(path: path),
                method: method,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Accept": "application/json",
                    "Content-Type": multipart.contentType,
                    "Content-Length": String(multipart.contentLength)
                ],
                bodyFileURL: multipart.bodyFileURL
            ),
            multipart: multipart
        )
    }
}
