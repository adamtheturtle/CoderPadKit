//
//  CoderPadClient+Organization.swift
//  CoderPadKit
//

import Foundation

public extension CoderPadClient {
    /// The organization's users. Passing `email` returns only the matching user, the
    /// reliable way to resolve which user an API key belongs to.
    ///
    /// When `email` is provided it is trimmed and domain-normalized, then rejected
    /// when not a plausible address, matching Screen email filters (#165).
    func organizationUsers(email: String? = nil) async throws -> [OrganizationUser] {
        guard !apiKey.isEmpty else { throw CoderPadError.missingAPIKey }

        let normalizedEmail = try Self.normalizedOrganizationUserEmail(email)
        var comps = URLComponents(url: baseURL.appending(path: "/api/organization/users"),
                                  resolvingAgainstBaseURL: false)
        if let normalizedEmail {
            comps?.queryItems = [URLQueryItem(name: "email", value: normalizedEmail)]
        }
        guard let url = comps?.url else { throw CoderPadError.http(0, "Invalid URL") }

        return try await rest.performWithRetry(
            OrganizationUsersWrapper.self, request: rest.authorizedGET(url)
        ).users
    }

    /// Trims and domain-lowercases an organization-user email filter, rejecting
    /// control characters and otherwise implausible addresses before they reach
    /// the query string (#165).
    nonisolated static func normalizedOrganizationUserEmail(_ email: String?) throws -> String? {
        guard let email else { return nil }
        let normalized = EmailValidation.normalized(email)
        guard EmailValidation.isPlausibleAddress(normalized) else {
            throw CoderPadError.decode("Organization user email filter is not a plausible address.")
        }
        return normalized
    }
}

private nonisolated struct OrganizationUsersWrapper: Decodable, Sendable {
    let users: [OrganizationUser]
}
