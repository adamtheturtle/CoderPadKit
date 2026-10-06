import Foundation

/// Display name and capabilities of the Interview API key owner.
/// `analyticsID` is an analytics identifier, rather than an email or login credential.
public nonisolated struct InterviewUser: Decodable, Hashable, Sendable {
    public let name: String?
    public let allowPadCreation: Bool
    public let analyticsID: String

    enum CodingKeys: String, CodingKey {
        case name
        case allowPadCreation = "allow_pad_creation"
        case analyticsID = "analytics_id"
    }
}

/// A team available to the Screen API key owner.
public nonisolated struct ScreenTeam: Decodable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDefault = "is_default"
    }
}

/// Organization, recruiter, and team identity of the Screen API key owner.
public nonisolated struct ScreenAccount: Decodable, Hashable, Sendable {
    public let organizationID: String
    public let recruiterID: String
    public let teams: [ScreenTeam]

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case recruiterID = "recruiter_id"
        case teams
    }
}

public extension CoderPadClient {
    /// Retrieve the Interview key owner's display name and pad-creation capability.
    func getUser() async throws -> InterviewUser {
        guard !apiKey.isEmpty else { throw CoderPadError.missingAPIKey }
        let url = baseURL.appending(path: "/api/user")
        return try await rest.performWithRetry(InterviewUser.self, request: rest.authorizedGET(url))
    }
}

public extension ScreenClient {
    /// Retrieve the organization, recruiter, and teams available to the Screen key.
    nonisolated func getMe() async throws -> ScreenAccount {
        try await get(ScreenAccount.self, path: "/me")
    }
}
