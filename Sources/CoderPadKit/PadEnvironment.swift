//
//  PadEnvironment.swift
//  CoderPadKit
//
//  Pad environment models and tolerant file_contents decoding.
//

import Foundation

/// One file within a pad environment. Single-file languages return one of these;
/// multi-file frameworks/projects return one per file in the project.
public nonisolated struct PadEnvironmentFile: Decodable, Hashable, Sendable {
    public let path: String?
    public let contents: String?
    /// Firebase URL for this file's editor history, when history is available.
    public let history: String?
    /// Whether the file is binary. A binary file commonly has `nil` ``contents``;
    /// this empirically observed flag distinguishes that from an empty text file.
    public let binary: Bool?
}

/// A single execution environment within a pad: a language, its files, and the
/// question (if any) it was seeded from.
public nonisolated struct PadEnvironment: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let padID: Int?
    public let questionID: Int?
    /// e.g. "examples/035-django-shopping-list" when seeded from a CoderPad example.
    public let exampleQuestionID: String?
    public let language: String?
    public let fileContents: [PadEnvironmentFile]
    /// Count of `file_contents` elements skipped because they were not valid
    /// ``PadEnvironmentFile`` values. Valid siblings are still retained.
    public let omittedFileCount: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, language
        case padID = "pad_id"
        case questionID = "question_id"
        case exampleQuestionID = "example_question_id"
        case fileContents = "file_contents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        padID = container.loggedDecodeIfPresent(Int.self, forKey: .padID)
        questionID = container.loggedDecodeIfPresent(Int.self, forKey: .questionID)
        exampleQuestionID = container.loggedDecodeIfPresent(String.self, forKey: .exampleQuestionID)
        language = container.loggedDecodeIfPresent(String.self, forKey: .language)
        let decodedFiles = container.decodeTolerantArrayIfPresent(
            PadEnvironmentFile.self, forKey: .fileContents
        )
        fileContents = decodedFiles.elements
        omittedFileCount = decodedFiles.omittedCount
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// Describes skipped malformed `file_contents` entries, when any were omitted.
    public var omittedFilesDiagnostic: String? {
        omittedJSONElementsDiagnostic(
            count: omittedFileCount,
            singular: "environment file",
            plural: "environment files"
        )
    }

    /// The combined code across all files in the environment, for a simple preview.
    /// Multi-file projects are concatenated with a header per file path.
    public var contents: String? {
        let files = fileContents.compactMap { file -> String? in
            guard let body = file.contents, !body.isEmpty else { return nil }

            if fileContents.count > 1, let path = file.path, !path.isEmpty {
                return "// \(path)\n\(body)"
            }
            return body
        }
        return files.isEmpty ? nil : files.joined(separator: "\n\n")
    }
}
