import Foundation

/// An ordered campaign question or randomly selected question set.
public nonisolated enum ScreenCampaignQuestion: Codable, Hashable, Sendable {
    case question(UUID)
    case randomQuestionSet(ScreenRandomQuestionConfiguration)

    enum CodingKeys: String, CodingKey {
        case type, configuration
        case questionID = "question_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "QUESTION":
            self = try .question(container.decode(UUID.self, forKey: .questionID))
        case "RANDOM_QUESTION_SET":
            self = try .randomQuestionSet(container.decode(ScreenRandomQuestionConfiguration.self,
                                                           forKey: .configuration))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Unknown campaign question type.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .question(id):
            try container.encode("QUESTION", forKey: .type)
            try container.encode(id, forKey: .questionID)
        case let .randomQuestionSet(configuration):
            guard configuration.includedQuestionIDs == nil || configuration.excludedQuestionIDs == nil else {
                throw CoderPadError.decode("Included and excluded question IDs are mutually exclusive.")
            }
            try container.encode("RANDOM_QUESTION_SET", forKey: .type)
            try container.encode(configuration, forKey: .configuration)
        }
    }
}

/// A campaign create request. Team defaults apply to omitted settings.
public nonisolated struct ScreenCampaignCreation: Encodable, Hashable, Sendable {
    public let name: String
    public let questions: [ScreenCampaignQuestion]
    public let settings: ScreenCampaignSettings?
    public let teamID: UUID?

    public init(name: String, questions: [ScreenCampaignQuestion],
                settings: ScreenCampaignSettings? = nil, teamID: UUID? = nil) {
        self.name = name
        self.questions = questions
        self.settings = settings
        self.teamID = teamID
    }

    enum CodingKeys: String, CodingKey {
        case name, questions, settings
        case teamID = "team_id"
    }
}

/// The integer identity returned with HTTP 201 after creation.
public nonisolated struct ScreenCreatedCampaign: Decodable, Hashable, Sendable {
    public let id: Int
}

public nonisolated extension ScreenClient {
    /// Creates a campaign with one request. Creation is never automatically retried.
    func createCampaign(_ campaign: ScreenCampaignCreation) async throws -> ScreenCreatedCampaign {
        guard (3 ... 64).contains(campaign.name.count), !campaign.questions.isEmpty else {
            throw CoderPadError.decode("Campaigns require a name of 3 to 64 characters and at least one question.")
        }
        return try await send(ScreenCreatedCampaign.self, method: "POST", path: "/campaigns", body: campaign)
    }
}
