import Foundation

/// Criteria for random campaign questions.
public nonisolated struct ScreenRandomQuestionConfiguration: Encodable, Hashable, Sendable {
    public enum QuestionType: String, Codable, Hashable, Sendable {
        case quiz = "QUIZ", code = "CODE"
    }

    public enum ExperienceLevel: String, Codable, Hashable, Sendable {
        case junior = "JUNIOR", senior = "SENIOR", expert = "EXPERT"
    }

    public let domain: String?
    public let skills: [String]?
    public let questionType: QuestionType?
    public let targetDurationMinutes: Int?
    public let targetExperienceLevel: ExperienceLevel?
    public let includedQuestionIDs: [UUID]?
    public let excludedQuestionIDs: [UUID]?

    public init(domain: String? = nil,
                skills: [String]? = nil,
                questionType: QuestionType? = nil,
                targetDurationMinutes: Int? = nil,
                targetExperienceLevel: ExperienceLevel? = nil,
                includedQuestionIDs: [UUID]? = nil,
                excludedQuestionIDs: [UUID]? = nil) {
        self.domain = domain
        self.skills = skills
        self.questionType = questionType
        self.targetDurationMinutes = targetDurationMinutes
        self.targetExperienceLevel = targetExperienceLevel
        self.includedQuestionIDs = includedQuestionIDs
        self.excludedQuestionIDs = excludedQuestionIDs
    }

    enum CodingKeys: String, CodingKey {
        case domain
        case skills
        case questionType = "question_type"
        case targetDurationMinutes = "target_duration_minutes"
        case targetExperienceLevel = "target_experience_level"
        case includedQuestionIDs = "included_question_ids"
        case excludedQuestionIDs = "excluded_question_ids"
    }
}

/// Timer overrides. Omitted fields use team defaults.
public nonisolated struct ScreenCampaignTimer: Encodable, Hashable, Sendable {
    public enum Mode: String, Codable, Hashable, Sendable {
        case perQuestion = "PER_QUESTION", global = "GLOBAL", unlimited = "UNLIMITED"
    }

    public let mode: Mode?
    public let durationMinutes: Int?

    public init(mode: Mode? = nil,
                durationMinutes: Int? = nil) {
        self.mode = mode
        self.durationMinutes = durationMinutes
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case durationMinutes = "duration_minutes"
    }
}

/// Access window with ISO 8601 timestamps.
public nonisolated struct ScreenCampaignAccessPeriod: Encodable, Hashable, Sendable {

    public let minStartTime: String?
    public let maxEndTime: String?

    public init(minStartTime: String? = nil,
                maxEndTime: String? = nil) {
        self.minStartTime = minStartTime
        self.maxEndTime = maxEndTime
    }

    enum CodingKeys: String, CodingKey {
        case minStartTime = "min_start_time"
        case maxEndTime = "max_end_time"
    }
}

/// Follow-up question settings.
public nonisolated struct ScreenCampaignFollowUpQuestions: Encodable, Hashable, Sendable {
    public enum AnswerFormat: String, Codable, Hashable, Sendable {
        case text = "TEXT", video = "VIDEO", audio = "AUDIO"
    }

    public let enabled: Bool?
    public let answerFormat: AnswerFormat?

    public init(enabled: Bool? = nil,
                answerFormat: AnswerFormat? = nil) {
        self.enabled = enabled
        self.answerFormat = answerFormat
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case answerFormat = "answer_format"
    }
}

/// Webcam and AI analysis settings.
public nonisolated struct ScreenCampaignWebcamProctoring: Encodable, Hashable, Sendable {

    public let enabled: Bool?
    public let aiAnalysisEnabled: Bool?

    public init(enabled: Bool? = nil,
                aiAnalysisEnabled: Bool? = nil) {
        self.enabled = enabled
        self.aiAnalysisEnabled = aiAnalysisEnabled
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case aiAnalysisEnabled = "ai_analysis_enabled"
    }
}

/// Campaign overrides. Nil inherits defaults, false and empty values remain explicit.
public nonisolated struct ScreenCampaignSettings: Encodable, Hashable, Sendable {

    public let languages: [String]?
    public let timer: ScreenCampaignTimer?
    public let invitationExpirationDays: Int?
    public let accessPeriod: ScreenCampaignAccessPeriod?
    public let sendCandidateSimplifiedReport: Bool?
    public let copyPasteBlocked: Bool?
    public let followUpQuestions: ScreenCampaignFollowUpQuestions?
    public let webcamProctoring: ScreenCampaignWebcamProctoring?
    public let fullScreenRequired: Bool?
    public let aiAssistEnabled: Bool?
    public let enabledCodingAgents: String?

    public init(languages: [String]? = nil,
                timer: ScreenCampaignTimer? = nil,
                invitationExpirationDays: Int? = nil,
                accessPeriod: ScreenCampaignAccessPeriod? = nil,
                sendCandidateSimplifiedReport: Bool? = nil,
                copyPasteBlocked: Bool? = nil,
                followUpQuestions: ScreenCampaignFollowUpQuestions? = nil,
                webcamProctoring: ScreenCampaignWebcamProctoring? = nil,
                fullScreenRequired: Bool? = nil,
                aiAssistEnabled: Bool? = nil,
                enabledCodingAgents: String? = nil) {
        self.languages = languages
        self.timer = timer
        self.invitationExpirationDays = invitationExpirationDays
        self.accessPeriod = accessPeriod
        self.sendCandidateSimplifiedReport = sendCandidateSimplifiedReport
        self.copyPasteBlocked = copyPasteBlocked
        self.followUpQuestions = followUpQuestions
        self.webcamProctoring = webcamProctoring
        self.fullScreenRequired = fullScreenRequired
        self.aiAssistEnabled = aiAssistEnabled
        self.enabledCodingAgents = enabledCodingAgents
    }

    enum CodingKeys: String, CodingKey {
        case languages
        case timer
        case invitationExpirationDays = "invitation_expiration_days"
        case accessPeriod = "access_period"
        case sendCandidateSimplifiedReport = "send_candidate_simplified_report"
        case copyPasteBlocked = "copy_paste_blocked"
        case followUpQuestions = "follow_up_questions"
        case webcamProctoring = "webcam_proctoring"
        case fullScreenRequired = "full_screen_required"
        case aiAssistEnabled = "ai_assist_enabled"
        case enabledCodingAgents = "enabled_coding_agents"
    }
}
