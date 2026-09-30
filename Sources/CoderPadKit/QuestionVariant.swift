import Foundation

/// A decoded starter file or a template overlay entry. Paths are already decoded by the API.
public nonisolated struct QuestionVariantFileContent: Codable, Hashable, Sendable {
    public var path: String
    public var contents: String
    public var hidden: Bool?
    public var deleted: Bool?

    public init(path: String, contents: String = "", hidden: Bool? = nil, deleted: Bool? = nil) {
        self.path = path
        self.contents = contents
        self.hidden = hidden
        self.deleted = deleted
    }
}

/// A language or project-template variant nested under a question.
public nonisolated struct QuestionVariant: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let questionID: Int
    public let language: String
    public let projectTemplateID: Int?
    public let projectTemplateSlug: String?
    public let display: String?
    public let contents: String?
    public let fileContents: [QuestionVariantFileContent]?
    public let solution: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, language, display, contents, solution
        case questionID = "question_id"
        case projectTemplateID = "project_template_id"
        case projectTemplateSlug = "project_template_slug"
        case fileContents = "file_contents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Whether to preserve starter code, write code (including a blank string), or restore the language default.
public nonisolated enum QuestionVariantContents: Equatable, Sendable {
    case unchanged
    case value(String)
    case languageDefault
}

/// JSON attributes shared by create and update. Create requires a language key or template slug.
/// Changing environments clears starter code unless replacement code is supplied in the same request.
/// Files overlay the template on create and replace files on update; an empty array resets a template variant.
public nonisolated struct QuestionVariantMutation: Encodable, Sendable {
    public var language: String?
    public var contents: QuestionVariantContents
    public var fileContents: [QuestionVariantFileContent]?
    public var solution: String?

    public init(language: String? = nil, contents: QuestionVariantContents = .unchanged,
                fileContents: [QuestionVariantFileContent]? = nil, solution: String? = nil) {
        self.language = language
        self.contents = contents
        self.fileContents = fileContents
        self.solution = solution
    }

    enum CodingKeys: String, CodingKey {
        case language, contents, solution
        case fileContents = "file_contents"
    }

    public func encode(to encoder: any Encoder) throws {
        if contents != .unchanged, fileContents != nil {
            throw QuestionMutationValidationError.mutuallyExclusiveContentSources
        }
        if let language, language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw EncodingError.invalidValue(language, .init(codingPath: encoder.codingPath,
                                                             debugDescription: "Variant language must not be blank."))
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(language, forKey: .language)
        switch contents {
        case .unchanged: break
        case let .value(value): try container.encode(value, forKey: .contents)
        case .languageDefault: try container.encodeNil(forKey: .contents)
        }
        try container.encodeIfPresent(fileContents, forKey: .fileContents)
        try container.encodeIfPresent(solution, forKey: .solution)
    }
}

nonisolated struct QuestionVariantsResponse: Decodable {
    let variants: [QuestionVariant]

    enum CodingKeys: String, CodingKey { case variants }

    init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            variants = try container.decode([QuestionVariant].self, forKey: .variants)
        } else {
            variants = try decoder.singleValueContainer().decode([QuestionVariant].self)
        }
    }
}
