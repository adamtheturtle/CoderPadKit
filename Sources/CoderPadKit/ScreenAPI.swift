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
    /// Count of `languages` elements that failed to decode as a string and
    /// were dropped rather than failing the whole campaign (#219).
    public let omittedLanguageCount: Int

    /// Memberwise init for tests and previews; enforces the same ID and name
    /// invariants as `init(from:)` (#140).
    public init(id: Int, name: String, languages: [String] = [], pinned: Bool = false, archived: Bool = false,
                omittedLanguageCount: Int = 0) throws {
        self.id = try validatedScreenModelID(id, kind: "campaign")
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw ScreenModelValidationError.blankCampaignName
        }
        self.name = normalizedName
        self.languages = languages
        self.pinned = pinned
        self.archived = archived
        self.omittedLanguageCount = omittedLanguageCount
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
        let decodedLanguages = try container.decodeIfPresent(TolerantScreenList<String>.self, forKey: .languages)
        languages = decodedLanguages?.elements ?? []
        omittedLanguageCount = decodedLanguages?.discardedCount ?? 0
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, languages, pinned, archived
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
    /// Count of `tags` elements that failed to decode as a string and were
    /// dropped rather than failing the whole session (#216).
    public let omittedTagCount: Int
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
    /// Count of `questions` elements that failed to decode and were dropped
    /// rather than failing the whole session (#215).
    public let omittedQuestionCount: Int
    /// e.g. "TO_REVIEW", once a human review workflow applies.
    public let approvalStatus: String?
    /// `true` when `report` was present but failed to decode, distinguishing
    /// that case from a candidate who simply has no report yet (#217).
    public let reportOmitted: Bool

    /// Memberwise init for tests and previews; enforces positive IDs and
    /// epoch-millisecond timestamp bounds like `init(from:)` (#141).
    public init(id: Int, status: String = "waiting", report: ScreenReport? = nil,
                candidateName: String? = nil, candidateEmail: String? = nil, tags: [String] = [],
                sendTime: Int? = nil, startTime: Int? = nil, endTime: Int? = nil,
                lastActivityTime: Int? = nil, campaignID: Int? = nil,
                url: String? = nil, testURL: String? = nil) throws {
        self.id = try validatedScreenModelID(id, kind: "test")
        self.status = status
        self.url = url
        self.report = report
        idTest = nil
        organizationID = nil
        if let campaignID {
            self.campaignID = try validatedScreenModelID(campaignID, kind: "campaign")
        } else {
            self.campaignID = nil
        }
        self.candidateName = candidateName
        self.candidateEmail = candidateEmail
        self.tags = tags
        self.sendTime = try ScreenEpochMilliseconds.validated(sendTime, name: "send_time")
        self.startTime = try ScreenEpochMilliseconds.validated(startTime, name: "start_time")
        self.endTime = try ScreenEpochMilliseconds.validated(endTime, name: "end_time")
        self.lastActivityTime = try ScreenEpochMilliseconds.validated(
            lastActivityTime, name: "last_activity_time"
        )
        try Self.validateChronology(
            sendTime: self.sendTime, startTime: self.startTime, endTime: self.endTime,
            lastActivityTime: self.lastActivityTime, codingPath: []
        )
        self.testURL = testURL
        candidateLanguage = nil
        questions = []
        omittedQuestionCount = 0
        omittedTagCount = 0
        approvalStatus = nil
        reportOmitted = false
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        url = try container.decodeIfPresent(String.self, forKey: .url)
        let reportKeyPresent = container.contains(.report)
        var reportPresent = false
        if reportKeyPresent {
            reportPresent = try !container.decodeNil(forKey: .report)
        }
        if reportPresent, let decodedReport = try? container.decode(ScreenReport.self, forKey: .report) {
            report = decodedReport
            reportOmitted = false
        } else {
            report = nil
            reportOmitted = reportPresent
        }
        id = try validatedScreenID(
            container.decode(Int.self, forKey: .id), codingPath: decoder.codingPath + [CodingKeys.id], kind: "test"
        )
        if let decodedIDTest = try container.decodeIfPresent(Int.self, forKey: .idTest) {
            let validated = try validatedScreenID(
                decodedIDTest, codingPath: decoder.codingPath + [CodingKeys.idTest], kind: "id_test"
            )
            guard validated == id else {
                throw DecodingError.dataCorruptedError(
                    forKey: .idTest, in: container,
                    debugDescription: "Screen id_test must equal id when present."
                )
            }
            idTest = validated
        } else {
            idTest = nil
        }
        let decodedOrganizationID = try container.decodeIfPresent(String.self, forKey: .organizationID)
        if let decodedOrganizationID, UUID(uuidString: decodedOrganizationID) == nil {
            throw DecodingError.dataCorruptedError(
                forKey: .organizationID, in: container,
                debugDescription: "Screen organization_id must be a canonical UUID when present."
            )
        }
        organizationID = decodedOrganizationID
        if let decodedCampaignID = try container.decodeIfPresent(Int.self, forKey: .campaignID) {
            campaignID = try validatedScreenID(
                decodedCampaignID, codingPath: decoder.codingPath + [CodingKeys.campaignID], kind: "campaign"
            )
        } else {
            campaignID = nil
        }
        candidateName = try container.decodeIfPresent(String.self, forKey: .candidateName)
        candidateEmail = try container.decodeIfPresent(String.self, forKey: .candidateEmail)
        let decodedTags = try container.decodeIfPresent(TolerantScreenList<String>.self, forKey: .tags)
        tags = decodedTags?.elements ?? []
        omittedTagCount = decodedTags?.discardedCount ?? 0
        sendTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .sendTime)
        startTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .startTime)
        endTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .endTime)
        lastActivityTime = try ScreenEpochMilliseconds.decode(from: container, forKey: .lastActivityTime)
        try Self.validateChronology(
            sendTime: sendTime, startTime: startTime, endTime: endTime,
            lastActivityTime: lastActivityTime, codingPath: decoder.codingPath
        )
        testURL = try container.decodeIfPresent(String.self, forKey: .testURL)
        candidateLanguage = try container.decodeIfPresent(String.self, forKey: .candidateLanguage)
        let decodedQuestions = try container.decodeIfPresent(
            TolerantScreenList<ScreenTestQuestion>.self, forKey: .questions
        )
        questions = decodedQuestions?.elements ?? []
        omittedQuestionCount = decodedQuestions?.discardedCount ?? 0
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

    let values: [String: Value]
    let discardedCount: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicScreenCodingKey.self)
        var decodedValues: [String: Value] = [:]
        var discardedCount = 0

        let keys = container.allKeys.sorted(by: { $0.stringValue < $1.stringValue })
        for key in keys {
            if decodedValues.count >= Self.maximumEntries {
                discardedCount += 1
                continue
            }

            guard let normalizedKey = normalizedScreenDictionaryKey(key.stringValue),
                  decodedValues[normalizedKey] == nil,
                  let value = try? container.decode(Value.self, forKey: key)
            else {
                discardedCount += 1
                continue
            }

            decodedValues[normalizedKey] = value
        }

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
    /// Count of `warnings` elements that failed to decode as a string, were blank
    /// after normalization, or exceeded the retained-warning cap and were dropped
    /// rather than failing the whole report (#218, #113).
    public let omittedWarningCount: Int

    /// Memberwise init for tests and previews; enforces the same metric invariants
    /// as `init(from:)` (#142).
    public init(score: Double? = nil, points: Int? = nil, duration: Int? = nil,
                warnings: [String] = [], technologies: [String: ScreenTechnologyResult] = [:],
                totalDuration: Int? = nil, totalPoints: Int? = nil,
                comparativeScore: Double? = nil, communityStats: [Int]? = nil,
                omittedBreakdownEntries: Int = 0, omittedWarningCount: Int = 0) throws {
        self.duration = try ScreenReportMetric.validatedNonnegative(duration, name: "duration")
        self.warnings = warnings
        self.points = try ScreenReportMetric.validatedNonnegative(points, name: "points")
        self.score = try ScreenReportMetric.validatedPercentage(score, name: "score")
        self.technologies = technologies
        self.omittedBreakdownEntries = try ScreenReportMetric.validatedNonnegative(
            omittedBreakdownEntries, name: "omittedBreakdownEntries"
        ) ?? 0
        self.totalDuration = try ScreenReportMetric.validatedNonnegative(
            totalDuration, name: "total_duration"
        )
        self.totalPoints = try ScreenReportMetric.validatedNonnegative(
            totalPoints, name: "total_points"
        )
        try ScreenReportMetric.requireAtMost(self.points, atMost: self.totalPoints, name: "points")
        try ScreenReportMetric.requireAtMost(
            self.duration, atMost: self.totalDuration, name: "duration"
        )
        self.comparativeScore = try ScreenReportMetric.validatedPercentage(
            comparativeScore, name: "comparative_score"
        )
        if let communityStats {
            guard communityStats.allSatisfy({ $0 >= 0 }) else {
                throw ScreenModelValidationError.invalidMetric(
                    "Screen report community_stats buckets must not be negative."
                )
            }
            self.communityStats = communityStats
        } else {
            self.communityStats = nil
        }
        self.omittedWarningCount = omittedWarningCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        duration = try ScreenReportMetric.nonnegativeInteger(from: container, forKey: .duration)
        let decodedWarnings = try container.decodeIfPresent(BoundedScreenWarnings.self, forKey: .warnings)
        warnings = decodedWarnings?.values ?? []
        omittedWarningCount = decodedWarnings?.discardedCount ?? 0
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
        try ScreenReportMetric.requireAtMost(
            points, atMost: totalPoints, forKey: .points, in: container,
            debugDescription: "Screen report points must not exceed total_points."
        )
        try ScreenReportMetric.requireAtMost(
            duration, atMost: totalDuration, forKey: .duration, in: container,
            debugDescription: "Screen report duration must not exceed total_duration."
        )
        comparativeScore = try ScreenReportMetric.percentage(from: container, forKey: .comparativeScore)
        communityStats = try ScreenReportMetric.decodeCommunityStats(from: container, forKey: .communityStats)
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
        try ScreenReportMetric.requireAtMost(
            points, atMost: totalPoints, forKey: .points, in: container,
            debugDescription: "Screen technology points must not exceed total_points."
        )
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
        try ScreenReportMetric.requireAtMost(
            points, atMost: totalPoints, forKey: .points, in: container,
            debugDescription: "Screen skill points must not exceed total_points."
        )
    }

    enum CodingKeys: String, CodingKey {
        case points, score
        case totalPoints = "total_points"
    }
}
