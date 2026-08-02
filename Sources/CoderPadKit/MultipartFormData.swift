//
//  MultipartFormData.swift
//  CoderPadKit
//
//  Byte-oriented multipart/form-data encoding shared by upload endpoints.
//

import Foundation

/// One text field in a multipart/form-data request.
nonisolated struct MultipartFormField: Sendable {
    let name: String
    let value: String
}

/// One binary file field in a multipart/form-data request.
nonisolated struct MultipartFormFile: Sendable {
    let name: String
    let filename: String
    let contentType: String
    let data: Data
}

/// A complete, in-memory multipart/form-data payload.
///
/// Encoding works only with values and bytes already supplied by the caller. It never
/// performs implicit file I/O, so constructing a request cannot block an actor on a
/// filesystem read.
nonisolated struct MultipartFormData: Sendable {
    let boundary: String
    let body: Data

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(
        fields: [MultipartFormField],
        files: [MultipartFormFile],
        boundary: String = "CoderPadKit-\(UUID().uuidString)"
    ) {
        self.boundary = boundary

        var body = Data()
        for field in fields {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8(
                "Content-Disposition: form-data; name=\"\(Self.quoted(field.name))\"\r\n\r\n"
            )
            body.appendUTF8(field.value)
            body.appendUTF8("\r\n")
        }
        for file in files {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8(
                "Content-Disposition: form-data; name=\"\(Self.quoted(file.name))\"; "
                    + "filename=\"\(Self.quoted(file.filename))\"\r\n"
                    + "Content-Type: \(file.contentType)\r\n\r\n"
            )
            body.append(file.data)
            body.appendUTF8("\r\n")
        }
        body.appendUTF8("--\(boundary)--\r\n")
        self.body = body
    }

    /// Escapes a quoted Content-Disposition parameter without losing Unicode.
    /// CR/LF are percent-escaped so a caller-controlled filename cannot inject a
    /// second multipart header.
    private static func quoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
    }
}

nonisolated extension QuestionCreate {
    func multipartFields() throws -> [MultipartFormField] {
        var fields = [MultipartFormField(name: "question[title]", value: title)]
        fields.append(name: "question[language]", value: language)
        fields.append(name: "question[description]", value: description)
        fields.append(name: "question[solution]", value: solution)
        fields.append(name: "question[contents]", value: contents)
        fields.append(name: "question[take_home]", value: takeHome.map(String.init))
        fields.append(name: "question[pad_type]", value: padType)
        fields.append(
            name: "question[candidate_instructions]",
            value: try candidateInstructions.map(Self.formJSONString)
        )
        fields.append(
            name: "question[ai_assist_custom_system_prompt]",
            value: aiAssistCustomSystemPrompt
        )
        return fields
    }

    private static func formJSONString(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

nonisolated extension QuestionUpdate {
    func multipartFields() throws -> [MultipartFormField] {
        var fields: [MultipartFormField] = []
        fields.append(name: "question[title]", value: title)
        fields.append(name: "question[language]", value: language)
        fields.append(name: "question[description]", value: description)
        fields.append(name: "question[solution]", value: solution)
        fields.append(name: "question[contents]", value: contents)
        fields.append(name: "question[take_home]", value: takeHome.map(String.init))
        fields.append(name: "question[pad_type]", value: padType)
        fields.append(
            name: "question[candidate_instructions]",
            value: try candidateInstructions.map(Self.formJSONString)
        )
        fields.append(
            name: "question[ai_assist_custom_system_prompt]",
            value: aiAssistCustomSystemPrompt
        )
        return fields
    }

    private static func formJSONString(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

private nonisolated extension Array where Element == MultipartFormField {
    mutating func append(name: String, value: String?) {
        guard let value else { return }
        append(MultipartFormField(name: name, value: value))
    }
}

private nonisolated extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }
}
