import Foundation

/// The reusable assessment definition, separate from a candidate's test session.
public nonisolated struct ScreenCampaignDetails: Decodable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let questions: [ScreenCampaignQuestion]
    public let settings: ScreenCampaignSettings?
    public let teamID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, questions, settings
        case teamID = "team_id"
    }
}

public nonisolated extension ScreenClient {
    /// Fetch the ordered questions, settings, and team of a campaign.
    func getCampaign(id: Int) async throws -> ScreenCampaignDetails {
        try Self.requirePositiveID(id, kind: "campaign")
        return try await get(ScreenCampaignDetails.self, path: "/campaigns/\(id)")
    }
}
