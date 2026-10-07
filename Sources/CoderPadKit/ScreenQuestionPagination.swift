import Foundation

/// Possibly partial offset metadata returned by the Screen question library.
public nonisolated struct ScreenQuestionPagination: Decodable, Hashable, Sendable {
    public let start: Int?
    public let limit: Int?
    public let total: Int?
    public let hasMoreItems: Bool?
    public let nextStart: Int?

    enum CodingKeys: String, CodingKey {
        case start, limit, total
        case hasMoreItems = "has_more_items"
        case nextStart = "next_start"
    }
}

/// Question details and the optional Location response header from creation.
public nonisolated struct ScreenCreatedQuestion: Hashable, Sendable {
    public let question: ScreenQuestionDetails
    public let location: String?
}
