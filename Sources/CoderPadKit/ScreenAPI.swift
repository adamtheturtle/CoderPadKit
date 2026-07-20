//
//  ScreenAPI.swift
//  coderpad
//
//  Models for the CoderPad Screen API (formerly CodinGame for Work),
//  documented at https://api.screen.coderpad.io. This is a *separate* product
//  from the Interview API modelled in the `CoderPadKit` package: it lives on a
//  different host (`https://www.codingame.com`, or `.eu` for EU customers),
//  authenticates with an `API-Key` header rather than a bearer token, and uses
//  offset-based pagination. The networking client is `ScreenClient`.
//
//  Optional fields are tolerant of API additions; required row identity remains strict.
//

import Foundation

// MARK: - Campaigns

/// A test campaign (a reusable assessment template) you can send to candidates.
/// Returned by `GET /campaigns`.
public nonisolated struct ScreenCampaign: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    /// Programming languages the candidate may answer in.
    public let languages: [String]
    public let pinned: Bool
    public let archived: Bool

    /// Memberwise init for tests and previews; the live decode path uses `init(from:)`.
    public init(id: Int, name: String, languages: [String] = [], pinned: Bool = false, archived: Bool = false) {
        self.id = id
        self.name = name
        self.languages = languages
        self.pinned = pinned
        self.archived = archived
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try validatedScreenID(
            container.decode(Int.self, forKey: .id), codingPath: decoder.codingPath + [CodingKeys.id], kind: "campaign"
        )
        let rawName = try container.decode(String.self, forKey: .name)
        let normalizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .name, in: container, debugDescription: "Screen campaign name must not be blank."
            )
        }

        name = normalizedName
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, languages, pinned, archived
    }
}

// MARK: - Sending invitations

/// The request body for `POST /campaigns/:id/actions/send`. All fields are
/// optional; omitting `candidateEmail` creates a test the recruiter can hand to
/// a candidate manually rather than emailing an invitation.
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
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        testURL = try container.decodeIfPresent(String.self, forKey: .testURL)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case testURL = "test_url"
    }
}

// MARK: - Test sessions

/// One candidate's run of a campaign. Returned (in a list) by `GET /tests` and
/// (singly) by `GET /tests/:id`. The `report` is populated once the candidate
/// finishes; before then most timing fields and the report are absent.
public nonisolated struct ScreenTestSession: Decodable, Identifiable, Hashable, Sendable {
    /// e.g. "waiting", "in_progress", "completed", "aborted", "cancelled".
    public var status: String
    /// Dashboard URL for a recruiter to review this candidate.
    public let url: String?
    public let report: ScreenReport?
    public let id: Int
    /// The underlying test id. Usually equal to `id`, but exposed verbatim.
    public let idTest: Int?
    public let organizationID: String?
    public let campaignID: Int?
    public let candidateName: String?
    public let candidateEmail: String?
    public let tags: [String]
    /// Epoch-millisecond timestamps; use the `*Date` accessors for `Date` values.
    public let sendTime: Int?
    public let startTime: Int?
    public let endTime: Int?
    public let lastActivityTime: Int?
    /// URL the candidate uses to take the test.
    public let testURL: String?
    /// The candidate's chosen UI language, e.g. "en".
    public let candidateLanguage: String?
    public let questions: [ScreenTestQuestion]
    /// e.g. "TO_REVIEW", once a human review workflow applies.
    public let approvalStatus: String?

    /// Memberwise init for tests and previews; the live decode path uses `init(from:)`.
    public init(id: Int, status: String = "waiting", report: ScreenReport? = nil,
         candidateName: String? = nil, candidateEmail: String? = nil, tags: [String] = [],
         sendTime: Int? = nil, startTime: Int? = nil, endTime: Int? = nil,
         lastActivityTime: Int? = nil, campaignID: Int? = nil,
         url: String? = nil, testURL: String? = nil) {
        self.id = id
        self.status = status
        self.url = url
        self.report = report
        idTest = nil
        organizationID = nil
        self.campaignID = campaignID
        self.candidateName = candidateName
        self.candidateEmail = candidateEmail
        self.tags = tags
        self.sendTime = sendTime
        self.startTime = startTime
        self.endTime = endTime
        self.lastActivityTime = lastActivityTime
        self.testURL = testURL
        candidateLanguage = nil
        questions = []
        approvalStatus = nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        url = try container.decodeIfPresent(String.self, forKey: .url)
        report = try container.decodeIfPresent(ScreenReport.self, forKey: .report)
        id = try validatedScreenID(
            container.decode(Int.self, forKey: .id), codingPath: decoder.codingPath + [CodingKeys.id], kind: "test"
        )
        idTest = try container.decodeIfPresent(Int.self, forKey: .idTest)
        organizationID = try container.decodeIfPresent(String.self, forKey: .organizationID)
        campaignID = try container.decodeIfPresent(Int.self, forKey: .campaignID)
        candidateName = try container.decodeIfPresent(String.self, forKey: .candidateName)
        candidateEmail = try container.decodeIfPresent(String.self, forKey: .candidateEmail)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        sendTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .sendTime)
        startTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .startTime)
        endTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .endTime)
        lastActivityTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .lastActivityTime)
        testURL = try container.decodeIfPresent(String.self, forKey: .testURL)
        candidateLanguage = try container.decodeIfPresent(String.self, forKey: .candidateLanguage)
        questions = try container.decodeIfPresent([ScreenTestQuestion].self, forKey: .questions) ?? []
        approvalStatus = try container.decodeIfPresent(String.self, forKey: .approvalStatus)
    }

    enum CodingKeys: String, CodingKey {
        case status, url, report, id, tags, questions
        case idTest = "id_test"
        case organizationID = "organization_id"
        case campaignID = "campaign_id"
        case candidateName = "candidate_name"
        case candidateEmail = "candidate_email"
        case sendTime = "send_time"
        case startTime = "start_time"
        case endTime = "end_time"
        case lastActivityTime = "last_activity_time"
        case testURL = "test_url"
        case candidateLanguage = "candidate_language"
        case approvalStatus = "approval_status"
    }
}

/// A question within a test session and when the candidate last touched it.
public nonisolated struct ScreenTestQuestion: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let lastActivityTime: Int?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try validatedScreenID(
            container.decode(Int.self, forKey: .id), codingPath: decoder.codingPath + [CodingKeys.id], kind: "question"
        )
        lastActivityTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .lastActivityTime)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case lastActivityTime = "last_activity_time"
    }
}

// MARK: - Reports

private nonisolated struct LenientScreenDictionary<Value: Decodable>: Decodable {
    private static var maximumEntries: Int {
        100
    }

    public let values: [String: Value]
    public let discardedCount: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicScreenCodingKey.self)
        var decodedValues: [String: Value] = [:]
        var discardedCount = 0

        let keys = container.allKeys.sorted(by: { $0.stringValue < $1.stringValue })
        for key in keys.prefix(Self.maximumEntries) {
            guard let normalizedKey = normalizedScreenDictionaryKey(key.stringValue),
                  decodedValues[normalizedKey] == nil,
                  let value = try? container.decode(Value.self, forKey: key)
            else {
                discardedCount += 1
                continue
            }

            decodedValues[normalizedKey] = value
        }

        discardedCount += max(0, keys.count - Self.maximumEntries)

        values = decodedValues
        self.discardedCount = discardedCount
    }
}

private extension KeyedDecodingContainer {
    public nonisolated func decodeLenientScreenDictionary<Value: Decodable>(
        of _: Value.Type,
        forKey key: Key
    ) -> (values: [String: Value], discardedCount: Int) {
        guard contains(key) else { return ([:], 0) }
        guard let decoded = try? decode(LenientScreenDictionary<Value>.self, forKey: key) else { return ([:], 1) }

        return (decoded.values, decoded.discardedCount)
    }
}

/// A candidate's scored results, present once the test is completed.
public nonisolated struct ScreenReport: Decodable, Hashable, Sendable {
    /// Time spent, in seconds.
    public let duration: Int?
    /// Proctoring/anti-cheat warnings raised during the test.
    public let warnings: [String]
    public let points: Int?
    /// Overall score as a percentage (0–100).
    public let score: Double?
    /// Per-technology breakdown, keyed by technology name (e.g. "Java").
    public let technologies: [String: ScreenTechnologyResult]
    public let omittedBreakdownEntries: Int
    public let totalDuration: Int?
    public let totalPoints: Int?
    public let comparativeScore: Double?
    /// Score distribution buckets across the candidate community, when requested
    /// with `withCommunityStats`.
    public let communityStats: [Int]?

    /// Memberwise init for tests and previews; the live decode path uses `init(from:)`.
    public init(score: Double? = nil, points: Int? = nil, duration: Int? = nil,
         warnings: [String] = [], technologies: [String: ScreenTechnologyResult] = [:],
         totalDuration: Int? = nil, totalPoints: Int? = nil,
         comparativeScore: Double? = nil, communityStats: [Int]? = nil,
         omittedBreakdownEntries: Int = 0) {
        self.duration = duration
        self.warnings = warnings
        self.points = points
        self.score = score
        self.technologies = technologies
        self.omittedBreakdownEntries = omittedBreakdownEntries
        self.totalDuration = totalDuration
        self.totalPoints = totalPoints
        self.comparativeScore = comparativeScore
        self.communityStats = communityStats
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        duration = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .duration)
        warnings = try container.decodeIfPresent(BoundedScreenWarnings.self, forKey: .warnings)?.values ?? []
        points = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .points)
        score = try ScreenReportMetric.percentage(from: container, forKey: .score)
        let decodedTechnologies = container.decodeLenientScreenDictionary(
            of: ScreenTechnologyResult.self, forKey: .technologies
        )
        technologies = decodedTechnologies.values
        omittedBreakdownEntries = decodedTechnologies.discardedCount
            + technologies.values.reduce(0) { $0 + $1.omittedSkillCount }
        totalDuration = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .totalDuration)
        totalPoints = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .totalPoints)
        comparativeScore = try ScreenReportMetric.percentage(from: container, forKey: .comparativeScore)
        communityStats = try container.decodeIfPresent([Int].self, forKey: .communityStats)
    }

    enum CodingKeys: String, CodingKey {
        case duration, warnings, points, score, technologies
        case totalDuration = "total_duration"
        case totalPoints = "total_points"
        case comparativeScore = "comparative_score"
        case communityStats = "community_stats"
    }
}

/// Per-technology results within a report, with a further per-skill breakdown.
public nonisolated struct ScreenTechnologyResult: Decodable, Hashable, Sendable {
    public let points: Int?
    public let score: Double?
    /// Per-skill breakdown, keyed by skill name (e.g. "Problem solving").
    public let skills: [String: ScreenSkillResult]
    public let omittedSkillCount: Int
    public let totalPoints: Int?
    public let comparativeScore: Double?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .points)
        score = try ScreenReportMetric.percentage(from: container, forKey: .score)
        let decodedSkills = container.decodeLenientScreenDictionary(of: ScreenSkillResult.self, forKey: .skills)
        skills = decodedSkills.values
        omittedSkillCount = decodedSkills.discardedCount
        totalPoints = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .totalPoints)
        comparativeScore = try ScreenReportMetric.percentage(from: container, forKey: .comparativeScore)
    }

    enum CodingKeys: String, CodingKey {
        case points, score, skills
        case totalPoints = "total_points"
        case comparativeScore = "comparative_score"
    }
}

/// A single skill's score within a technology result.
public nonisolated struct ScreenSkillResult: Decodable, Hashable, Sendable {
    public let points: Int?
    public let score: Double?
    public let totalPoints: Int?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .points)
        score = try ScreenReportMetric.percentage(from: container, forKey: .score)
        totalPoints = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .totalPoints)
    }

    enum CodingKeys: String, CodingKey {
        case points, score
        case totalPoints = "total_points"
    }
}
