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
        let decodedFiles = Self.decodeFileContents(from: container)
        fileContents = decodedFiles.files
        omittedFileCount = decodedFiles.omittedCount
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// Describes skipped malformed `file_contents` entries, when any were omitted.
    public var omittedFilesDiagnostic: String? {
        guard omittedFileCount > 0 else { return nil }

        let noun = omittedFileCount == 1 ? "file" : "files"
        return "Ignored \(omittedFileCount) malformed environment \(noun)."
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

    private static func decodeFileContents(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> (files: [PadEnvironmentFile], omittedCount: Int) {
        guard container.contains(.fileContents) else {
            return ([], 0)
        }

        do {
            var filesContainer = try container.nestedUnkeyedContainer(forKey: .fileContents)
            var files: [PadEnvironmentFile] = []
            var omittedCount = 0
            while !filesContainer.isAtEnd {
                if let file = try? filesContainer.decode(PadEnvironmentFile.self) {
                    files.append(file)
                } else if (try? filesContainer.decode(DiscardedJSONValue.self)) == nil {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: filesContainer.codingPath,
                        debugDescription: "Pad environment file_contents contained an unreadable value."
                    ))
                } else {
                    omittedCount += 1
                }
            }
            return (files, omittedCount)
        } catch {
            apiLogger.debug(
                """
                decodeIfPresent 'file_contents' \
                as [PadEnvironmentFile] \
                failed: \(error.localizedDescription)
                """
            )
            return ([], 0)
        }
    }
}

/// Advances a decoder past one JSON value so tolerant array decoding can skip a
/// malformed element without abandoning the rest of the array.
private nonisolated struct DiscardedJSONValue: Decodable {
    private static let maximumNestingDepth = 64

    init(from decoder: any Decoder) throws {
        guard decoder.codingPath.count <= Self.maximumNestingDepth else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Discarded JSON value exceeded the nesting limit."
            ))
        }

        if var array = try? decoder.unkeyedContainer() {
            while !array.isAtEnd {
                _ = try array.decode(Self.self)
            }
            return
        }

        if let object = try? decoder.container(keyedBy: DiscardedJSONCodingKey.self) {
            for key in object.allKeys {
                _ = try object.decode(Self.self, forKey: key)
            }
            return
        }

        _ = try? decoder.singleValueContainer()
    }
}

private nonisolated struct DiscardedJSONCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
