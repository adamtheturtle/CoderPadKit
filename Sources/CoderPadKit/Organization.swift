//
//  Organization.swift
//  CoderPadKit
//
//  The organization, its users, usage stats, and quota.
//

import Foundation

/// A CoderPad organization: its users, teams, and SSO configuration.
public nonisolated struct Organization: Decodable, Hashable, Sendable {
    public let id: Int
    public let organizationName: String
    public let userCount: Int?
    public let users: [OrganizationUser]
    public let teams: [PadTeam]
    public let organizationDefaultLanguage: String?
    public let singleSignOnSupported: Bool?
    /// URL of the organization's SSO sign-in portal, when SSO is supported.
    public let singleSignInURL: String?

    enum CodingKeys: String, CodingKey {
        case id, users, teams
        case organizationName = "organization_name"
        case userCount = "user_count"
        case organizationDefaultLanguage = "organization_default_language"
        case singleSignOnSupported = "single_sign_on_supported"
        case singleSignInURL = "single_sign_in_url"
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
}
