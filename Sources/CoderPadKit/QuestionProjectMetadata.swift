import Foundation

/// Parent-question starter files. Contents may be absent for template deletion entries.
public nonisolated struct QuestionStarterFile: Codable, Hashable, Sendable {
    public let path: String
    public let contents: String?
    public let hidden: Bool?
    public let deleted: Bool?
}

/// Compact metadata returned with a parent question, without required code or timestamps.
public nonisolated struct QuestionVariantSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let language: String?
    public let projectTemplateID: Int?
    public let projectTemplateSlug: String?
    public let display: String?

    enum CodingKeys: String, CodingKey {
        case id, language, display
        case projectTemplateID = "project_template_id"
        case projectTemplateSlug = "project_template_slug"
    }
}
