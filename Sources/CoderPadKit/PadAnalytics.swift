import Foundation

/// Structured JSON whose shape is owned by the service, such as an interview outline.
public nonisolated enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: Self].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([Self].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

/// One spoken transcript entry or system message. Timestamps are epoch milliseconds.
public nonisolated struct TranscriptEntry: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case transcript
        case systemMessage = "system_message"
    }

    public let id: String
    public let kind: Kind
    public let speakerName: String?
    public let speakerRole: String?
    public let text: String
    public let timestamp: Int64

    public init(
        id: String, kind: Kind, speakerName: String? = nil, speakerRole: String? = nil,
        text: String, timestamp: Int64
    ) {
        self.id = id
        self.kind = kind
        self.speakerName = speakerName
        self.speakerRole = speakerRole
        self.text = text
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, text, timestamp
        case speakerName = "speaker_name"
        case speakerRole = "speaker_role"
    }
}

/// An owner-visible review, including pending reports and generation failures.
public nonisolated struct ReviewReport: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let status: String
    public let title: String?
    public let prompt: String?
    public let report: String?
    public let summary: String?
    public let icon: String?
    public let error: String?
    public let userID: Int?
    public let filePaths: [String]?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String, status: String, title: String? = nil, prompt: String? = nil,
        report: String? = nil, summary: String? = nil, icon: String? = nil, error: String? = nil,
        userID: Int? = nil, filePaths: [String]? = nil, createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id
        self.status = status
        self.title = title
        self.prompt = prompt
        self.report = report
        self.summary = summary
        self.icon = icon
        self.error = error
        self.userID = userID
        self.filePaths = filePaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, status, title, prompt, report, summary, icon, error
        case userID = "user_id"
        case filePaths = "file_paths"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
