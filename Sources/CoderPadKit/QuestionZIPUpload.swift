//
//  QuestionZIPUpload.swift
//  CoderPadKit
//
//  ZIP upload value, size/filename validation, and multipart size errors.
//

import Foundation

/// ZIP bytes to attach when creating or updating a multi-file question.
///
/// The value is deliberately data-oriented: CoderPadKit does not open the filename or
/// read from disk. Obtain `data` from a file, memory, or another provider before calling
/// ``CoderPadClient/createQuestion(_:zipFile:)`` or
/// ``CoderPadClient/updateQuestion(_:zipFile:)``.
public nonisolated struct QuestionZIPUpload: Sendable {
    /// Maximum accepted archive size (50 MiB).
    public static let maximumByteCount = 50 * 1024 * 1024
    /// Maximum complete multipart body size, including the archive, text fields, and
    /// framing. Text fields cannot use this headroom to bypass the archive ceiling.
    public static let maximumMultipartByteCount = maximumByteCount + (5 * 1024 * 1024)

    /// The exact archive bytes sent to CoderPad. Must be a minimally valid ZIP
    /// structure: either a local file header (`PK\x03\x04`) or the end-of-central-
    /// directory record of an empty archive (`PK\x05\x06`). Empty `Data` is rejected.
    public var data: Data
    /// The filename reported in the multipart Content-Disposition header.
    /// Must be a nonempty printable basename with no control or format characters.
    public var filename: String

    /// The four-byte local file header signature that begins every non-empty ZIP
    /// archive.
    private static let localFileHeaderSignature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
    /// The four-byte end-of-central-directory signature. An archive with no entries
    /// is exactly this signature followed by 18 zero bytes.
    private static let endOfCentralDirectorySignature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]

    public init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    func validate() throws {
        try validateFilename()
        try validateSize()
        try validateArchiveStructure()
    }

    func validateSize() throws {
        guard data.count <= Self.maximumByteCount else {
            throw QuestionZIPUploadTooLargeError(
                byteCount: data.count,
                limit: Self.maximumByteCount
            )
        }
    }

    func validateArchiveStructure() throws {
        let prefix = [UInt8](data.prefix(4))
        guard prefix == Self.localFileHeaderSignature || prefix == Self.endOfCentralDirectorySignature else {
            throw QuestionZIPUploadInvalidArchiveError(byteCount: data.count)
        }
    }

    func validateFilename() throws {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw QuestionZIPUploadInvalidFilenameError(filename: filename)
        }
        guard !trimmed.contains("/"), !trimmed.contains("\\") else {
            throw QuestionZIPUploadInvalidFilenameError(filename: filename)
        }
        for character in trimmed {
            if character.isASCII, let ascii = character.asciiValue, ascii < 0x20 || ascii == 0x7F {
                throw QuestionZIPUploadInvalidFilenameError(filename: filename)
            }
            if character.unicodeScalars.contains(where: { scalar in
                let category = scalar.properties.generalCategory
                return category == .control || category == .format
            }) {
                throw QuestionZIPUploadInvalidFilenameError(filename: filename)
            }
        }
    }
}

/// A question ZIP exceeded ``QuestionZIPUpload/maximumByteCount``.
public nonisolated struct QuestionZIPUploadTooLargeError: LocalizedError, Equatable, Sendable {
    public let byteCount: Int
    public let limit: Int

    public var errorDescription: String? {
        "Question ZIP is \(byteCount) bytes; the upload limit is \(limit) bytes."
    }

    public init(byteCount: Int, limit: Int) {
        self.byteCount = byteCount
        self.limit = limit
    }
}

/// A question ZIP's data was empty or did not begin with a recognized ZIP
/// signature (a local file header or the end-of-central-directory record of an
/// empty archive).
public nonisolated struct QuestionZIPUploadInvalidArchiveError: LocalizedError, Equatable, Sendable {
    public let byteCount: Int

    public var errorDescription: String? {
        "Question ZIP data (\(byteCount) bytes) is not a minimally valid ZIP archive."
    }

    public init(byteCount: Int) {
        self.byteCount = byteCount
    }
}

/// A question ZIP filename was empty, contained a path separator, or included a
/// nonprinting control/format character.
public nonisolated struct QuestionZIPUploadInvalidFilenameError: LocalizedError, Equatable, Sendable {
    public let filename: String

    public var errorDescription: String? {
        "Question ZIP filename must be a nonempty printable basename."
    }

    public init(filename: String) {
        self.filename = filename
    }
}

/// A staged multipart body exceeded ``QuestionZIPUpload/maximumMultipartByteCount``.
public nonisolated struct MultipartFormDataTooLargeError: LocalizedError, Equatable, Sendable {
    public let byteCount: Int
    public let limit: Int

    public var errorDescription: String? {
        "Multipart upload is \(byteCount) bytes; the request limit is \(limit) bytes."
    }

    public init(byteCount: Int, limit: Int) {
        self.byteCount = byteCount
        self.limit = limit
    }
}
