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
    /// Creates a project pad from a ZIP archive, using the same bounds as question uploads.
    /// Use structured files when also supplying an interviewer access list.
    func createPad(_ body: PadCreate, zipFile: QuestionZIPUpload) async throws -> Pad {
        guard body.allowedInterviewerEmails == nil else {
            throw CoderPadError.decode(
                "Use structured files to combine project creation with an interviewer access list."
            )
        }
        let encoded = try Self.makeEncoder().encode(body)
        let values = try JSONDecoder().decode([String: JSONValue].self, from: encoded)
        let fields = try values.sorted(by: { $0.key < $1.key }).map { key, value in
            let text: String
            if case let .string(string) = value {
                text = string
            } else {
                text = String(decoding: try Self.makeEncoder().encode(value), as: UTF8.self)
            }
            return MultipartFormField(name: "pad[\(key)]", value: text)
        }
        let request = try multipartQuestionRequest(
            method: "POST", path: "/api/pads/", fields: fields,
            hasAlternativeContentSource: body.contents != nil || body.fileContents != nil || body.questionID != nil,
            zipFile: zipFile, fieldName: "pad[zip_file]"
        )
        defer { request.remove() }
        return try await rest.perform(Pad.self, request: request.request)
    }

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
        zipFile: QuestionZIPUpload,
        fieldName: String = "question[zip_file]"
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
                    name: fieldName,
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
