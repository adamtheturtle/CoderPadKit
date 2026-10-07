import Foundation

/// One ordered message with the original structured AI output retained.
public nonisolated struct ScreenAIMessage: Decodable, Hashable, Sendable {
    public enum Role: String, Decodable, Hashable, Sendable {
        case user = "USER", assistant = "ASSISTANT"
    }

    public let id: String
    public let role: Role
    /// Original ISO 8601 string, including the returned precision and offset.
    public let creationTime: String?
    /// Nil when absent, empty when explicitly empty. Unknown nested output fields are preserved.
    public let outputItems: [JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, role
        case creationTime = "creation_time"
        case outputItems = "output_items"
    }
}

/// A candidate PROJECT question's conversation with AI Assist, preserving message order.
public nonisolated struct ScreenAIConversation: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let subject: String?
    public let creationTime: String?
    public let messages: [ScreenAIMessage]

    enum CodingKeys: String, CodingKey {
        case id, subject, messages
        case creationTime = "creation_time"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        creationTime = try container.decodeIfPresent(String.self, forKey: .creationTime)
        messages = try container.decodeIfPresent([ScreenAIMessage].self, forKey: .messages) ?? []
    }
}

public nonisolated extension ScreenClient {
    /// Conversations are available after completion or while awaiting manual review.
    /// Missing PROJECT questions return 404 and unfinished sessions return 409.
    func aiAssistConversations(testID: Int, questionID: UUID) async throws -> [ScreenAIConversation] {
        try Self.requirePositiveID(testID, kind: "test")
        let path = "/tests/\(testID)/questions/\(questionID.uuidString.lowercased())/ai-assist-conversations"
        return try await get([ScreenAIConversation].self, path: path)
    }
}
