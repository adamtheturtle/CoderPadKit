import Foundation

/// A warning with an open identifier and a severity level.
public nonisolated struct ScreenQuestionWarning: Decodable, Hashable, Sendable {
    public let type: String?
    public let level: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case type
        case level
        case message
    }
}

/// An AI recommendation or the reason no recommendation was produced.
public nonisolated struct ScreenAIReview: Decodable, Hashable, Sendable {
    public let rationale: String?
    public let recommendedOutcome: String?
    public let noRecommendationReason: String?

    enum CodingKeys: String, CodingKey {
        case rationale
        case recommendedOutcome = "recommended_outcome"
        case noRecommendationReason = "no_recommendation_reason"
    }
}

/// A rubric verdict, awarded points, and optional AI recommendation.
public nonisolated struct ScreenRubricCriterionResult: Decodable, Hashable, Sendable {
    public let label: String?
    public let description: String?
    public let skill: String?
    public let outcome: String?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let resultMessage: String?
    public let resultOverriddenByRecruiter: Bool?
    public let reviewMode: String?
    public let aiReview: ScreenAIReview?

    enum CodingKeys: String, CodingKey {
        case label
        case description
        case skill
        case outcome
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case resultMessage = "result_message"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
        case reviewMode = "review_mode"
        case aiReview = "ai_review"
    }
}

/// Ordered criterion results from a rubric review.
public nonisolated struct ScreenRubricResult: Decodable, Hashable, Sendable {
    public let criteria: [ScreenRubricCriterionResult]?

    enum CodingKeys: String, CodingKey {
        case criteria
    }
}

/// A project test verdict with its stable key and output.
public nonisolated struct ScreenTestReportCaseResult: Decodable, Hashable, Sendable {
    public let key: String?
    public let label: String?
    public let skill: String?
    public let outcome: String?
    public let output: String?
    public let testIdentifier: String?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let resultOverriddenByRecruiter: Bool?

    enum CodingKeys: String, CodingKey {
        case key
        case label
        case skill
        case outcome
        case output
        case testIdentifier = "test_identifier"
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
    }
}

/// Ordered results from the project test suite.
public nonisolated struct ScreenTestReportResult: Decodable, Hashable, Sendable {
    public let testCases: [ScreenTestReportCaseResult]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// A validation method result with timing and override indicators.
public nonisolated struct ScreenValidationCodeCaseResult: Decodable, Hashable, Sendable {
    public let label: String?
    public let skill: String?
    public let outcome: String?
    public let testIdentifier: String?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let resultMessage: String?
    public let resultOverriddenByRecruiter: Bool?
    public let timedOut: Bool?

    enum CodingKeys: String, CodingKey {
        case label
        case skill
        case outcome
        case testIdentifier = "test_identifier"
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case resultMessage = "result_message"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
        case timedOut = "timed_out"
    }
}

/// Ordered validation results, including flattened nested cases.
public nonisolated struct ScreenValidationCodeResult: Decodable, Hashable, Sendable {
    public let testCases: [ScreenValidationCodeCaseResult]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// An output comparison result with points and a display message.
public nonisolated struct ScreenInputOutputCaseResult: Decodable, Hashable, Sendable {
    public let label: String?
    public let skill: String?
    public let outcome: String?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let resultMessage: String?
    public let resultOverriddenByRecruiter: Bool?
    public let timedOut: Bool?

    enum CodingKeys: String, CodingKey {
        case label
        case skill
        case outcome
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case resultMessage = "result_message"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
        case timedOut = "timed_out"
    }
}

/// Ordered results comparing program output with expected output.
public nonisolated struct ScreenInputOutputResult: Decodable, Hashable, Sendable {
    public let testCases: [ScreenInputOutputCaseResult]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// A database query comparison verdict and its points.
public nonisolated struct ScreenSQLComparisonResult: Decodable, Hashable, Sendable {
    public let outcome: String?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let resultMessage: String?
    public let resultOverriddenByRecruiter: Bool?
    public let timedOut: Bool?

    enum CodingKeys: String, CodingKey {
        case outcome
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case resultMessage = "result_message"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
        case timedOut = "timed_out"
    }
}

/// An accepted text value with exact or regular expression matching.
public nonisolated struct ScreenAcceptedAnswer: Decodable, Hashable, Sendable {
    public let value: String?
    public let matchType: String?

    enum CodingKeys: String, CodingKey {
        case value
        case matchType = "match_type"
    }
}

/// Accepted values used to match the submitted text.
public nonisolated struct ScreenTextAnswerMatchingResult: Decodable, Hashable, Sendable {
    public let acceptedAnswers: [ScreenAcceptedAnswer]?

    enum CodingKeys: String, CodingKey {
        case acceptedAnswers = "accepted_answers"
    }
}

/// Correct indexes into the question choices.
public nonisolated struct ScreenChoiceSelectionResult: Decodable, Hashable, Sendable {
    public let correctChoiceIndexes: [Int]?

    enum CodingKeys: String, CodingKey {
        case correctChoiceIndexes = "correct_choice_indexes"
    }
}

/// Optional grading methods and their individual results.
public nonisolated struct ScreenQuestionEvaluation: Decodable, Hashable, Sendable {
    public let rubric: ScreenRubricResult?
    public let testReport: ScreenTestReportResult?
    public let validationCode: ScreenValidationCodeResult?
    public let inputOutput: ScreenInputOutputResult?
    public let sqlQueryResultComparison: ScreenSQLComparisonResult?
    public let textAnswerMatching: ScreenTextAnswerMatchingResult?
    public let choiceSelection: ScreenChoiceSelectionResult?

    enum CodingKeys: String, CodingKey {
        case rubric
        case testReport = "test_report"
        case validationCode = "validation_code"
        case inputOutput = "input_output"
        case sqlQueryResultComparison = "sql_query_result_comparison"
        case textAnswerMatching = "text_answer_matching"
        case choiceSelection = "choice_selection"
    }
}

/// Submitted code and the chosen programming language.
public nonisolated struct ScreenCodeAnswer: Decodable, Hashable, Sendable {
    public let code: String?
    public let programmingLanguageID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case programmingLanguageID = "programming_language_id"
    }
}

/// Submitted game code and the chosen programming language.
public nonisolated struct ScreenGameAnswer: Decodable, Hashable, Sendable {
    public let code: String?
    public let programmingLanguageID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case programmingLanguageID = "programming_language_id"
    }
}

/// Selected indexes into the ordered question choices.
public nonisolated struct ScreenMCQAnswer: Decodable, Hashable, Sendable {
    public let selectedChoiceIndexes: [Int]?

    enum CodingKeys: String, CodingKey {
        case selectedChoiceIndexes = "selected_choice_indexes"
    }
}

/// The candidate's submitted free text.
public nonisolated struct ScreenTextAnswer: Decodable, Hashable, Sendable {
    public let text: String?

    enum CodingKeys: String, CodingKey {
        case text
    }
}

/// An uploaded file, a temporary URL, and an optional comment.
public nonisolated struct ScreenFileUploadAnswer: Decodable, Hashable, Sendable {
    public let filename: String?
    public let downloadURL: String?
    public let candidateComment: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case downloadURL = "download_url"
        case candidateComment = "candidate_comment"
    }
}

/// An authenticated archive endpoint and an AI conversation count.
public nonisolated struct ScreenProjectAnswer: Decodable, Hashable, Sendable {
    public let downloadURL: String?
    public let aiAssistConversationCount: Int?

    enum CodingKeys: String, CodingKey {
        case downloadURL = "download_url"
        case aiAssistConversationCount = "ai_assist_conversation_count"
    }
}

/// A recording with temporary media and transcript URLs.
public nonisolated struct ScreenRecording: Decodable, Hashable, Sendable {
    public let id: String?
    public let url: String?
    public let transcriptURL: String?
    public let durationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case transcriptURL = "transcript_url"
        case durationSeconds = "duration_seconds"
    }
}

/// Recording availability, ordered recordings, and a candidate comment.
public nonisolated struct ScreenVideoAnswer: Decodable, Hashable, Sendable {
    public let recordings: [ScreenRecording]?
    public let recordingAvailability: String?
    public let candidateComment: String?

    enum CodingKeys: String, CodingKey {
        case recordings
        case recordingAvailability = "recording_availability"
        case candidateComment = "candidate_comment"
    }
}

/// Candidate submissions grouped by question type.
public nonisolated struct ScreenQuestionAnswer: Decodable, Hashable, Sendable {
    public let codeAnswer: ScreenCodeAnswer?
    public let gameAnswer: ScreenGameAnswer?
    public let mcqAnswer: ScreenMCQAnswer?
    public let textAnswer: ScreenTextAnswer?
    public let fileUploadAnswer: ScreenFileUploadAnswer?
    public let projectAnswer: ScreenProjectAnswer?
    public let videoAnswer: ScreenVideoAnswer?

    enum CodingKeys: String, CodingKey {
        case codeAnswer = "code_answer"
        case gameAnswer = "game_answer"
        case mcqAnswer = "mcq_answer"
        case textAnswer = "text_answer"
        case fileUploadAnswer = "file_upload_answer"
        case projectAnswer = "project_answer"
        case videoAnswer = "video_answer"
    }
}

/// A choice label in the language used by the candidate.
public nonisolated struct ScreenMCQChoice: Decodable, Hashable, Sendable {
    public let label: String?

    enum CodingKeys: String, CodingKey {
        case label
    }
}

/// Ordered choices and selection settings for the answered question.
public nonisolated struct ScreenMCQResultDetails: Decodable, Hashable, Sendable {
    public let choices: [ScreenMCQChoice]?
    public let selectionMode: String?
    public let randomizeChoices: Bool?

    enum CodingKeys: String, CodingKey {
        case choices
        case selectionMode = "selection_mode"
        case randomizeChoices = "randomize_choices"
    }
}

/// A UUID question with candidate answers, grading, and activity data.
public nonisolated struct ScreenDetailedQuestion: Decodable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let version: Int?
    public let type: String?
    public let title: String?
    public let domain: String?
    public let warnings: [ScreenQuestionWarning]?
    public let evaluation: ScreenQuestionEvaluation?
    public let answer: ScreenQuestionAnswer?
    public let maxPoints: Int?
    public let awardedPoints: Int?
    public let timeLimitSeconds: Int?
    public let timeSpentSeconds: Int?
    public let firstAccessTime: Int?
    public let submissionTime: Int?
    public let lastActivityTime: Int?
    public let answerStatus: String?
    public let gradingStatus: String?
    public let timedOut: Bool?
    public let resultOverriddenByRecruiter: Bool?
    public let markedAsCheatedByRecruiter: Bool?
    public let timeSpentOutsideEnvironmentSeconds: Int?
    public let environmentExitCount: Int?
    public let mcqDetails: ScreenMCQResultDetails?

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case type
        case title
        case domain
        case warnings
        case evaluation
        case answer
        case maxPoints = "max_points"
        case awardedPoints = "awarded_points"
        case timeLimitSeconds = "time_limit_seconds"
        case timeSpentSeconds = "time_spent_seconds"
        case firstAccessTime = "first_access_time"
        case submissionTime = "submission_time"
        case lastActivityTime = "last_activity_time"
        case answerStatus = "answer_status"
        case gradingStatus = "grading_status"
        case timedOut = "timed_out"
        case resultOverriddenByRecruiter = "result_overridden_by_recruiter"
        case markedAsCheatedByRecruiter = "marked_as_cheated_by_recruiter"
        case timeSpentOutsideEnvironmentSeconds = "time_spent_outside_environment_seconds"
        case environmentExitCount = "environment_exit_count"
        case mcqDetails = "mcq_details"
    }
}
