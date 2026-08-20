//
//  Organization.swift
//  CoderPadKit
//
//  The organization, its users, usage stats, and quota.
//

import Foundation

/// A CoderPad organization: its users, teams, and SSO configuration.
public nonisolated struct Organization: Decodable, Hashable, Sendable {
    // The live response also carries `child_organizations`, but its sampled value
    // was empty. Deliberately defer a public property until a non-empty response
    // establishes the item shape instead of publishing a speculative wire model.
    /// Organization numeric id when the payload includes one. The documented
    /// `/api/organization` example omits `id`, so this is optional (#152).
    public let id: Int?
    public let organizationName: String
    public let userCount: Int?
    public let users: [OrganizationUser]
    public let teams: [PadTeam]
    public let organizationDefaultLanguage: String?
    public let singleSignOnSupported: Bool?
    /// URL of the organization's SSO sign-in portal, when SSO is supported.
    public let singleSignInURL: String?

    enum CodingKeys: String, CodingKey {
        case id, users, teams, name
        case organizationName = "organization_name"
        case userCount = "user_count"
        case organizationDefaultLanguage = "organization_default_language"
        case defaultLanguage = "default_language"
        case singleSignOnSupported = "single_sign_on_supported"
        case singleSignInURL = "single_sign_in_url"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawID = try container.decodeIfPresent(Int.self, forKey: .id) {
            guard rawID > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: container,
                    debugDescription: "Organization id must be positive when present."
                )
            }
            id = rawID
        } else {
            id = nil
        }
        organizationName =
            try container.decodeIfPresent(String.self, forKey: .organizationName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? ""
        userCount = try container.decodeIfPresent(NonnegativeInt.self, forKey: .userCount)?.value
        users = try container.decodeIfPresent([OrganizationUser].self, forKey: .users) ?? []
        teams = try container.decodeIfPresent([PadTeam].self, forKey: .teams) ?? []
        organizationDefaultLanguage =
            try container.decodeIfPresent(String.self, forKey: .organizationDefaultLanguage)
            ?? container.decodeIfPresent(String.self, forKey: .defaultLanguage)
        singleSignOnSupported = try container.decodeIfPresent(Bool.self, forKey: .singleSignOnSupported)
        singleSignInURL = try container.decodeIfPresent(String.self, forKey: .singleSignInURL)
    }
}

/// A user within an organization.
public nonisolated struct OrganizationUser: Decodable, Identifiable, Hashable, Sendable {
    public var id: String {
        email
    }

    public let email: String
    public let name: String?
    public let teams: [String]?
    public let padsCreated: Int?

    enum CodingKeys: String, CodingKey {
        case email, name, teams
        case padsCreated = "pads_created"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        teams = try container.decodeIfPresent([String].self, forKey: .teams)
        padsCreated = try container.decodeIfPresent(NonnegativeInt.self, forKey: .padsCreated)?.value
    }
}

/// Pad-usage statistics for an organization over a time window.
public nonisolated struct OrganizationStats: Decodable, Hashable, Sendable {
    public let startTime: Date?
    public let endTime: Date?
    public let padsCreated: Int
    public let users: [OrganizationUser]

    enum CodingKeys: String, CodingKey {
        case users
        case startTime = "start_time"
        case endTime = "end_time"
        case padsCreated = "pads_created"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        padsCreated = try container.decode(NonnegativeInt.self, forKey: .padsCreated).value
        users = try container.decode([OrganizationUser].self, forKey: .users)
    }
}

/// The account's pad quota for the current billing cycle.
public nonisolated struct Quota: Decodable, Hashable, Sendable {
    public let trialExpiresAt: Date?
    public let padsUsed: Int?
    public let quotaReset: Date?
    public let unlimited: Bool?
    public let overagesEnabled: Bool?
    /// Pads left in the current billing cycle. Absent (nil) when `unlimited` is true.
    public let padsRemaining: Int?
    /// Total pads allocated for the billing cycle. Absent (nil) when `unlimited` is true.
    public let billingCyclePadLimit: Int?

    enum CodingKeys: String, CodingKey {
        case unlimited
        case trialExpiresAt = "trial_expires_at"
        case padsUsed = "pads_used"
        case quotaReset = "quota_reset_at"
        case overagesEnabled = "overages_enabled"
        case padsRemaining = "pads_remaining"
        case billingCyclePadLimit = "billing_cycle_pad_limit"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trialExpiresAt = try container.decodeIfPresent(Date.self, forKey: .trialExpiresAt)
        padsUsed = try container.decodeIfPresent(NonnegativeInt.self, forKey: .padsUsed)?.value
        quotaReset = try container.decodeIfPresent(Date.self, forKey: .quotaReset)
        unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited)
        overagesEnabled = try container.decodeIfPresent(Bool.self, forKey: .overagesEnabled)
        padsRemaining = try container.decodeIfPresent(NonnegativeInt.self, forKey: .padsRemaining)?.value
        billingCyclePadLimit = try container.decodeIfPresent(
            NonnegativeInt.self, forKey: .billingCyclePadLimit
        )?.value
        if let padsRemaining, let billingCyclePadLimit, padsRemaining > billingCyclePadLimit {
            throw DecodingError.dataCorruptedError(
                forKey: .padsRemaining,
                in: container,
                debugDescription: "pads_remaining must not exceed billing_cycle_pad_limit."
            )
        }
    }
}
