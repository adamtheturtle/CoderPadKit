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

/// A complete multipart/form-data payload staged in a private temporary file.
///
/// The caller's file `Data` is written directly to the file handle rather than appended
/// to a second aggregate `Data`, keeping peak resident memory close to the source archive.
nonisolated struct MultipartFormData: Sendable {
    let boundary: String
    let stagingFolder: URL
    let bodyFileURL: URL
    let contentLength: Int

    static var stagingRoot: URL {
        FileManager.default.temporaryDirectory
            .appending(path: "CoderPadQuestionUploads", directoryHint: .isDirectory)
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(
        fields: [MultipartFormField],
        files: [MultipartFormFile],
        boundary: String? = nil
    ) throws {
        let stagingIdentifier = UUID().uuidString
        self.boundary = boundary ?? "CoderPadKit-\(stagingIdentifier)"
        let folder = Self.stagingRoot.appending(path: stagingIdentifier, directoryHint: .isDirectory)
        let fileURL = folder.appending(path: "multipart.body")
        stagingFolder = folder
        bodyFileURL = fileURL

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            guard FileManager.default.createFile(
                atPath: fileURL.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            ) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            do {
                var byteCount = 0
                for field in fields {
                    try Self.writeUTF8("--\(self.boundary)\r\n", to: handle, byteCount: &byteCount)
                    try Self.writeUTF8(
                        "Content-Disposition: form-data; name=\"\(Self.quoted(field.name))\"\r\n\r\n",
                        to: handle,
                        byteCount: &byteCount
                    )
                    try Self.writeUTF8(field.value, to: handle, byteCount: &byteCount)
                    try Self.writeUTF8("\r\n", to: handle, byteCount: &byteCount)
                }
                for file in files {
                    try Self.writeUTF8("--\(self.boundary)\r\n", to: handle, byteCount: &byteCount)
                    try Self.writeUTF8(
                        "Content-Disposition: form-data; name=\"\(Self.quoted(file.name))\"; "
                            + "\(Self.contentDispositionFilename(file.filename))\r\n"
                            + "Content-Type: \(file.contentType)\r\n\r\n",
                        to: handle,
                        byteCount: &byteCount
                    )
                    try Self.write(file.data, to: handle, byteCount: &byteCount)
                    try Self.writeUTF8("\r\n", to: handle, byteCount: &byteCount)
                }
                try Self.writeUTF8("--\(self.boundary)--\r\n", to: handle, byteCount: &byteCount)
                try handle.close()
                contentLength = byteCount
            } catch {
                try? handle.close()
                throw error
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: stagingFolder)
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

    /// ASCII `filename` plus RFC 5987 `filename*` when the original name is not ASCII.
    private static func contentDispositionFilename(_ filename: String) -> String {
        if filename.utf8.allSatisfy({ $0 < 0x80 }) {
            return "filename=\"\(quoted(filename))\""
        }

        let fallback = String(filename.map { character in
            character.isASCII ? character : "_"
        })
        return "filename=\"\(quoted(fallback))\"; filename*=UTF-8''\(rfc5987Encode(filename))"
    }

    /// Percent-encodes a filename for an RFC 5987 `filename*` parameter value.
    private static func rfc5987Encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$&+-.^_`|~"
        )
        var encoded = ""
        for byte in value.utf8 {
            let scalar = UnicodeScalar(byte)
            if allowed.contains(scalar) {
                encoded.append(Character(scalar))
            } else {
                encoded.append(String(format: "%%%02X", byte))
            }
        }
        return encoded
    }

    private static func writeUTF8(_ value: String, to handle: FileHandle, byteCount: inout Int) throws {
        try write(Data(value.utf8), to: handle, byteCount: &byteCount)
    }

    private static func write(_ data: Data, to handle: FileHandle, byteCount: inout Int) throws {
        let (nextCount, overflow) = byteCount.addingReportingOverflow(data.count)
        let limit = QuestionZIPUpload.maximumMultipartByteCount
        if overflow || nextCount > limit {
            throw MultipartFormDataTooLargeError(
                byteCount: overflow ? Int.max : nextCount,
                limit: limit
            )
        }
        try handle.write(contentsOf: data)
        byteCount = nextCount
    }
}

nonisolated extension QuestionCreate {
    func multipartFields() throws -> [MultipartFormField] {
        try validateTakeHomePadType(takeHome: takeHome, padType: padType)
        let normalizedLanguage = try InterviewLanguage.validated(
            language, allowUnknown: allowUnknownLanguage
        )
        var fields = [MultipartFormField(name: "question[title]", value: try validatedQuestionTitle(title))]
        fields.append(name: "question[language]", value: normalizedLanguage)
        // Only title/language nest under `question[]`; remaining fields are flat (#153).
        fields.append(name: "description", value: description)
        fields.append(name: "solution", value: solution)
        fields.append(name: "contents", value: contents)
        fields.append(name: "take_home", value: takeHome.map(String.init))
        fields.append(name: "pad_type", value: padType)
        fields.append(
            name: "candidate_instructions",
            value: try validatedCandidateInstructions(candidateInstructions).map(Self.formJSONString)
        )
        fields.append(name: "ai_assist_custom_system_prompt", value: aiAssistCustomSystemPrompt)
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
        try validateTakeHomePadType(takeHome: takeHome, padType: padType)
        let normalizedLanguage = try InterviewLanguage.validated(
            language, allowUnknown: allowUnknownLanguage
        )
        var fields: [MultipartFormField] = []
        fields.append(name: "question[title]", value: try title.map(validatedQuestionTitle))
        fields.append(name: "question[language]", value: normalizedLanguage)
        fields.append(name: "description", value: description)
        fields.append(name: "solution", value: solution)
        fields.append(name: "contents", value: contents)
        fields.append(name: "take_home", value: takeHome.map(String.init))
        fields.append(name: "pad_type", value: padType)
        fields.append(
            name: "candidate_instructions",
            value: try validatedCandidateInstructions(candidateInstructions).map(Self.formJSONString)
        )
        fields.append(name: "ai_assist_custom_system_prompt", value: aiAssistCustomSystemPrompt)
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
