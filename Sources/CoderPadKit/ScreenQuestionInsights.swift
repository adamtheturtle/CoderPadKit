import Foundation

/// Optional statistics returned by the Screen question insights API.
public nonisolated struct ScreenQuestionUsageInsights: Decodable, Hashable, Sendable {
    public let viewCount: Int?
    public let lastViewTime: String?
    public let averageAnswerDurationSeconds: Int?
    public let timeoutRate: Double?
    public let averageScore: Double?

    enum CodingKeys: String, CodingKey {
        case viewCount = "view_count"
        case lastViewTime = "last_view_time"
        case averageAnswerDurationSeconds = "average_answer_duration_seconds"
        case timeoutRate = "timeout_rate"
        case averageScore = "average_score"
    }
}

/// Optional statistics returned by the Screen question insights API.
public nonisolated struct ScreenQuestionRepartitionInsights: Decodable, Hashable, Sendable {
    public let label: String?
    public let count: Int?
    public let percentage: Double?
    public let correct: Bool?

    enum CodingKeys: String, CodingKey {
        case label
        case count
        case percentage
        case correct
    }
}

/// Optional statistics returned by the Screen question insights API.
public nonisolated struct ScreenQuestionScoreRangeInsights: Decodable, Hashable, Sendable {
    public let scoreRange: String?
    public let candidateCount: Int?

    enum CodingKeys: String, CodingKey {
        case scoreRange = "score_range"
        case candidateCount = "candidate_count"
    }
}

/// Optional statistics returned by the Screen question insights API.
public nonisolated struct ScreenQuestionScoresDistributionInsights: Decodable, Hashable, Sendable {
    public let distribution: [ScreenQuestionScoreRangeInsights]?
    public let totalCandidates: Int?

    enum CodingKeys: String, CodingKey {
        case distribution
        case totalCandidates = "total_candidates"
    }
}

/// Optional statistics returned by the Screen question insights API.
public nonisolated struct ScreenQuestionInsights: Decodable, Hashable, Sendable {
    public let id: String?
    public let usage: ScreenQuestionUsageInsights?
    public let frequentAnswers: [ScreenQuestionRepartitionInsights]?
    public let testcasesSuccess: [ScreenQuestionRepartitionInsights]?
    public let scoresDistribution: ScreenQuestionScoresDistributionInsights?

    enum CodingKeys: String, CodingKey {
        case id
        case usage
        case frequentAnswers = "frequent_answers"
        case testcasesSuccess = "testcases_success"
        case scoresDistribution = "scores_distribution"
    }
}
