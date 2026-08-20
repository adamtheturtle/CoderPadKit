//
//  MultipartFormData.swift
//  CoderPadKit
//
//  Byte-oriented multipart/form-data encoding shared by upload endpoints.
//  Question ZIP bodies are staged under a private temporary root with the same
//  registry / retry / leftover-sweep pattern as Screen report PDFs (#139).
//

import Foundation
import Synchronization

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
    private static let logger = CoderPadLogger(category: "question-uploads")

    /// Folders staged by this process (keyed by their unique directory name), each
    /// with its scheduled removal task when one exists. The registry keeps the launch
    /// sweep from deleting a body staged concurrently, lets an explicit removal cancel
    /// its now-pointless scheduled retry, and makes both paths idempotent (#139).
    private static let active = Mutex([String: Task<Void, Never>?]())

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
        try self.init(fields: fields, files: files, boundary: boundary, afterCreatingFolder: { _ in })
    }

    /// Same as ``init(fields:files:boundary:)``, with a hook after the staging folder
    /// exists so tests can exercise the leftover sweep without racing the write.
    init(
        fields: [MultipartFormField],
        files: [MultipartFormFile],
        boundary: String? = nil,
        afterCreatingFolder: @Sendable (URL) -> Void
    ) throws {
        // Sweep abandoned staging from earlier runs whenever the library stages again.
        Self.cleanUpLeftovers()

        let stagingIdentifier = UUID().uuidString
        self.boundary = boundary ?? "CoderPadKit-\(stagingIdentifier)"
        let folder = Self.stagingRoot.appending(path: stagingIdentifier, directoryHint: .isDirectory)
        let fileURL = folder.appending(path: "multipart.body")
        stagingFolder = folder
        bodyFileURL = fileURL

        // Reserve the name before the directory becomes visible so a concurrent
        // leftover sweep cannot mistake an in-progress write for abandoned data.
        Self.active.withLock { $0[stagingIdentifier] = .some(nil) }
        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            afterCreatingFolder(folder)
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
            _ = Self.active.withLock { $0.removeValue(forKey: stagingIdentifier) }
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// Removes this staging folder, retrying on deletion failure (#139).
    func remove() {
        Self.remove(stagingFolder, retryAfter: .seconds(30)) {
            try FileManager.default.removeItem(at: $0)
        }
    }

    /// Removes one staged upload folder, cancelling any removal still scheduled for it.
    static func remove(
        _ folder: URL,
        retryAfter: Duration,
        removeItem: @escaping @Sendable (URL) throws -> Void
    ) {
        // Only ever delete inside the staging root: a caller passing an unexpected
        // URL must not be able to remove an arbitrary parent directory.
        guard let staged = stagedFolder(folder) else {
            logger.error("Refused to remove a question upload outside the staging root.")
            return
        }

        let name = staged.lastPathComponent
        let scheduled = active.withLock { $0.removeValue(forKey: name) }
        if let scheduled, let scheduled { scheduled.cancel() }
        do {
            try removeItem(staged)
        } catch CocoaError.fileNoSuchFile {
            // Already swept; both cleanup paths are idempotent.
        } catch {
            // Keep a retry registered so the launch sweep cannot mistake sensitive
            // data from this process for an abandoned directory and race it.
            logger.error("Couldn't remove a staged question upload: \(error.localizedDescription)")
            scheduleRemovalAttempt(
                of: staged,
                after: retryAfter,
                retryAfter: retryAfter,
                removeItem: removeItem
            )
        }
    }

    /// Launch-time (and re-use) sweep of uploads left behind by earlier runs.
    /// Folders staged by this process are skipped so a late sweep can't race a
    /// concurrently built multipart body (#139).
    static func cleanUpLeftovers() {
        let manager = FileManager.default
        let entries: [URL]
        do {
            entries = try manager.contentsOfDirectory(at: stagingRoot, includingPropertiesForKeys: nil)
        } catch CocoaError.fileReadNoSuchFile {
            return
        } catch {
            logger.error("Couldn't sweep leftover question uploads: \(error.localizedDescription)")
            return
        }

        let live = active.withLock { Set($0.keys) }
        for entry in entries where !live.contains(entry.lastPathComponent) {
            do {
                try manager.removeItem(at: entry)
            } catch {
                logger.error("Couldn't sweep a leftover question upload: \(error.localizedDescription)")
            }
        }
    }

    private static func scheduleRemovalAttempt(
        of folder: URL,
        after duration: Duration,
        retryAfter: Duration,
        removeItem: @escaping @Sendable (URL) throws -> Void
    ) {
        guard let staged = stagedFolder(folder) else {
            logger.error("Refused to schedule removal outside the staging root.")
            return
        }
        let name = staged.lastPathComponent
        let task = Task.detached(priority: .utility) {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }

            remove(staged, retryAfter: retryAfter, removeItem: removeItem)
        }
        active.withLock { registry in
            if let previous = registry[name], let previous { previous.cancel() }
            registry[name] = task
        }
    }

    /// Returns `folder` only when it is a direct child of the staging root.
    private static func stagedFolder(_ folder: URL) -> URL? {
        let standardized = folder.standardizedFileURL
        guard standardized.deletingLastPathComponent().standardizedFileURL.path
            == stagingRoot.standardizedFileURL.path else { return nil }
        return standardized
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
        var fields = [MultipartFormField(name: "question[title]", value: try validatedQuestionTitle(title))]
        fields.append(name: "question[language]", value: language)
        fields.append(name: "question[description]", value: description)
        fields.append(name: "question[solution]", value: solution)
        fields.append(name: "question[contents]", value: contents)
        fields.append(name: "question[take_home]", value: takeHome.map(String.init))
        fields.append(name: "question[pad_type]", value: padType)
        fields.append(
            name: "question[candidate_instructions]",
            value: try validatedCandidateInstructions(candidateInstructions).map(Self.formJSONString)
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
        fields.append(name: "question[title]", value: try title.map(validatedQuestionTitle))
        fields.append(name: "question[language]", value: language)
        fields.append(name: "question[description]", value: description)
        fields.append(name: "question[solution]", value: solution)
        fields.append(name: "question[contents]", value: contents)
        fields.append(name: "question[take_home]", value: takeHome.map(String.init))
        fields.append(name: "question[pad_type]", value: padType)
        fields.append(
            name: "question[candidate_instructions]",
            value: try validatedCandidateInstructions(candidateInstructions).map(Self.formJSONString)
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
