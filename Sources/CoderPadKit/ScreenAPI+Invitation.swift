//
//  ScreenAPI+Invitation.swift
//  coderpad
//

import Foundation

/// Documented `report_type` values for Screen PDF export (#106).
public nonisolated enum ScreenReportType: String, CaseIterable, Hashable, Sendable {
    case full
    case simplified
}

/// The request body for `POST /campaigns/:id/actions/send`. All fields are
/// optional; omitting `candidateEmail` creates a test the recruiter can hand to
/// a candidate manually rather than emailing an invitation.
///
/// `candidateName` must be at most ``ScreenClient/maximumCandidateNameLength``
/// characters; longer values fail locally as the service's `CandidateNameTooLong`.
public nonisolated struct ScreenInvitation: Encodable, Hashable, Sendable {
    public var candidateEmail: String?
    public var candidateName: String?
    /// Recruiter who receives the result notification.
    public var recruiterEmail: String?
    /// Free-form tags, sent as a single string per the API contract.
    public var tags: String?
    public var sendInvitationEmail: Bool?
    public var sendNotificationEmailOnBounce: Bool?

    public init(candidateEmail: String? = nil,
                candidateName: String? = nil,
                recruiterEmail: String? = nil,
                tags: String? = nil,
                sendInvitationEmail: Bool? = nil,
                sendNotificationEmailOnBounce: Bool? = nil) {
        self.candidateEmail = candidateEmail
        self.candidateName = candidateName
        self.recruiterEmail = recruiterEmail
        self.tags = tags
        self.sendInvitationEmail = sendInvitationEmail
        self.sendNotificationEmailOnBounce = sendNotificationEmailOnBounce
    }

    enum CodingKeys: String, CodingKey {
        case candidateEmail = "candidate_email"
        case candidateName = "candidate_name"
        case recruiterEmail = "recruiter_email"
        case tags
        case sendInvitationEmail = "send_invitation_email"
        case sendNotificationEmailOnBounce = "send_notification_email_on_bounce"
    }
}

/// The result of sending an invitation: the URL the candidate uses to take it,
/// and, when returned, the new test session id.
public nonisolated struct ScreenInvitationResult: Decodable, Hashable, Sendable {
    public let id: Int?
    public let testURL: String?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decodeIfPresent(Int.self, forKey: .id)
        if let decodedID {
            id = try validatedScreenID(decodedID, codingPath: decoder.codingPath + [CodingKeys.id], kind: "invitation")
        } else {
            id = nil
        }
        if let rawTestURL = try container.decodeIfPresent(String.self, forKey: .testURL) {
            let normalizedTestURL = rawTestURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTestURL.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .testURL, in: container,
                    debugDescription: "Screen invitation test_url must not be blank."
                )
            }
            testURL = normalizedTestURL
        } else {
            testURL = nil
        }
        guard id != nil || testURL != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .testURL, in: container,
                debugDescription: "Screen invitation result must include an id or a test_url."
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case testURL = "test_url"
    }
}
