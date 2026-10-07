import Foundation

/// Typed question summary returned by the question library.
public nonisolated struct ScreenQuestionSummary: Decodable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let version: Int?
    public let title: [String: String]?
    public let type: String?
    public let difficulty: String?
    public let domain: String?
    public let skill: String?
    public let product: String?
    public let durationSeconds: Int?
    public let programmingLanguageID: String?
    public let modificationTime: String?
    public let fromCoderPadQuestionBank: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case title
        case type
        case difficulty
        case domain
        case skill
        case product
        case durationSeconds = "duration_seconds"
        case programmingLanguageID = "programming_language_id"
        case modificationTime = "modification_time"
        case fromCoderPadQuestionBank = "from_coderpad_question_bank"
    }
}

/// Typed question resource details returned by the question library.
public nonisolated struct ScreenQuestionResourceDetails: Decodable, Hashable, Sendable {
    public let filename: String?
    public let mimeType: String?
    public let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case downloadUrl = "download_url"
    }
}

/// Typed rubric criterion details returned by the question library.
public nonisolated struct ScreenRubricCriterionDetails: Decodable, Hashable, Sendable {
    public let label: [String: String]?
    public let skill: String?
    public let points: Int?
    public let weight: Int?
    public let reviewMode: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case label
        case skill
        case points
        case weight
        case reviewMode = "review_mode"
        case description
    }
}

/// Typed rubric details returned by the question library.
public nonisolated struct ScreenRubricDetails: Decodable, Hashable, Sendable {
    public let criteria: [ScreenRubricCriterionDetails]?

    enum CodingKeys: String, CodingKey {
        case criteria
    }
}

/// Typed test report test case details returned by the question library.
public nonisolated struct ScreenTestReportTestCaseDetails: Decodable, Hashable, Sendable {
    public let key: String?
    public let testIdentifier: String?
    public let label: [String: String]?
    public let skill: String?
    public let points: Int?
    public let weight: Int?

    enum CodingKeys: String, CodingKey {
        case key
        case testIdentifier = "test_identifier"
        case label
        case skill
        case points
        case weight
    }
}

/// Typed test report details returned by the question library.
public nonisolated struct ScreenTestReportDetails: Decodable, Hashable, Sendable {
    public let testCases: [ScreenTestReportTestCaseDetails]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// Typed validation code test case details returned by the question library.
public nonisolated struct ScreenValidationCodeTestCaseDetails: Decodable, Hashable, Sendable {
    public let label: [String: String]?
    public let testIdentifier: String?
    public let skill: String?
    public let points: Int?
    public let weight: Int?
    public let difficulty: Int?
    public let contributesToScore: Bool?
    public let visibleToCandidate: Bool?

    enum CodingKeys: String, CodingKey {
        case label
        case testIdentifier = "test_identifier"
        case skill
        case points
        case weight
        case difficulty
        case contributesToScore = "contributes_to_score"
        case visibleToCandidate = "visible_to_candidate"
    }
}

/// Typed validation code details returned by the question library.
public nonisolated struct ScreenValidationCodeDetails: Decodable, Hashable, Sendable {
    public let testCases: [ScreenValidationCodeTestCaseDetails]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// Typed input output test case details returned by the question library.
public nonisolated struct ScreenInputOutputTestCaseDetails: Decodable, Hashable, Sendable {
    public let label: [String: String]?
    public let input: String?
    public let output: String?
    public let skill: String?
    public let points: Int?
    public let weight: Int?
    public let difficulty: Int?
    public let contributesToScore: Bool?
    public let visibleToCandidate: Bool?
    public let timeoutMSByProgrammingLanguageID: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case label
        case input
        case output
        case skill
        case points
        case weight
        case difficulty
        case contributesToScore = "contributes_to_score"
        case visibleToCandidate = "visible_to_candidate"
        case timeoutMSByProgrammingLanguageID = "timeout_ms_by_programming_language_id"
    }
}

/// Typed input output details returned by the question library.
public nonisolated struct ScreenInputOutputDetails: Decodable, Hashable, Sendable {
    public let testCases: [ScreenInputOutputTestCaseDetails]?

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// Typed query comparison rules details returned by the question library.
public nonisolated struct ScreenQueryComparisonRulesDetails: Decodable, Hashable, Sendable {
    public let rowOrderMatters: Bool?
    public let columnOrderMatters: Bool?
    public let compareAllTables: Bool?

    enum CodingKeys: String, CodingKey {
        case rowOrderMatters = "row_order_matters"
        case columnOrderMatters = "column_order_matters"
        case compareAllTables = "compare_all_tables"
    }
}

/// Typed SQL query result comparison details returned by the question library.
public nonisolated struct ScreenSQLQueryResultComparisonDetails: Decodable, Hashable, Sendable {
    public let referenceQuery: String?
    public let comparison: ScreenQueryComparisonRulesDetails?

    enum CodingKeys: String, CodingKey {
        case referenceQuery = "reference_query"
        case comparison
    }
}

/// Typed evaluation accepted answer details returned by the question library.
public nonisolated struct ScreenEvaluationAcceptedAnswerDetails: Decodable, Hashable, Sendable {
    public let value: String?
    public let matchType: String?

    enum CodingKeys: String, CodingKey {
        case value
        case matchType = "match_type"
    }
}

/// Typed text answer matching details returned by the question library.
public nonisolated struct ScreenTextAnswerMatchingDetails: Decodable, Hashable, Sendable {
    public let acceptedAnswers: [ScreenEvaluationAcceptedAnswerDetails]?

    enum CodingKeys: String, CodingKey {
        case acceptedAnswers = "accepted_answers"
    }
}

/// Typed choice selection details returned by the question library.
public nonisolated struct ScreenChoiceSelectionDetails: Decodable, Hashable, Sendable {
    public let correctChoiceIndexes: [Int]?

    enum CodingKeys: String, CodingKey {
        case correctChoiceIndexes = "correct_choice_indexes"
    }
}

/// Typed evaluation details returned by the question library.
public nonisolated struct ScreenEvaluationDetails: Decodable, Hashable, Sendable {
    public let rubric: ScreenRubricDetails?
    public let testReport: ScreenTestReportDetails?
    public let validationCode: ScreenValidationCodeDetails?
    public let inputOutput: ScreenInputOutputDetails?
    public let sqlQueryResultComparison: ScreenSQLQueryResultComparisonDetails?
    public let textAnswerMatching: ScreenTextAnswerMatchingDetails?
    public let choiceSelection: ScreenChoiceSelectionDetails?

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

/// Typed question choice details returned by the question library.
public nonisolated struct ScreenQuestionChoiceDetails: Decodable, Hashable, Sendable {
    public let label: [String: String]?

    enum CodingKeys: String, CodingKey {
        case label
    }
}

/// Typed multiple choice details returned by the question library.
public nonisolated struct ScreenMCQDetails: Decodable, Hashable, Sendable {
    public let choices: [ScreenQuestionChoiceDetails]?
    public let selectionMode: String?
    public let randomizeChoices: Bool?

    enum CodingKeys: String, CodingKey {
        case choices
        case selectionMode = "selection_mode"
        case randomizeChoices = "randomize_choices"
    }
}

/// Typed environment details returned by the question library.
public nonisolated struct ScreenEnvironmentDetails: Decodable, Hashable, Sendable {
    public let version: String?
    public let environmentID: String?

    enum CodingKeys: String, CodingKey {
        case version
        case environmentID = "environment_id"
    }
}

/// Typed database engine details returned by the question library.
public nonisolated struct ScreenDatabaseEngineDetails: Decodable, Hashable, Sendable {
    public let version: String?
    public let engineID: String?

    enum CodingKeys: String, CodingKey {
        case version
        case engineID = "engine_id"
    }
}

/// Typed function signature details returned by the question library.
public nonisolated struct ScreenFunctionSignatureDetails: Decodable, Hashable, Sendable {
    public let name: String?
    public let parameters: [[String: JSONValue]]?
    public let returnType: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case name
        case parameters
        case returnType = "return_type"
    }
}

/// Typed possible solution details returned by the question library.
public nonisolated struct ScreenPossibleSolutionDetails: Decodable, Hashable, Sendable {
    public let code: String?
    public let programmingLanguageID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case programmingLanguageID = "programming_language_id"
    }
}

/// Typed code details returned by the question library.
public nonisolated struct ScreenCodeDetails: Decodable, Hashable, Sendable {
    public let environment: ScreenEnvironmentDetails?
    public let mode: String?
    public let programmingLanguageID: String?
    public let candidateTestCode: String?
    public let validatorCode: String?
    public let timeoutMS: Int?
    public let databaseEngine: ScreenDatabaseEngineDetails?
    public let databaseSetupScript: String?
    public let starterCode: String?
    public let functionSignature: ScreenFunctionSignatureDetails?
    public let possibleSolution: ScreenPossibleSolutionDetails?
    public let showFunctionSignatureInStatement: Bool?
    public let availableProgrammingLanguageIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case environment
        case mode
        case programmingLanguageID = "programming_language_id"
        case candidateTestCode = "candidate_test_code"
        case validatorCode = "validator_code"
        case timeoutMS = "timeout_ms"
        case databaseEngine = "database_engine"
        case databaseSetupScript = "database_setup_script"
        case starterCode = "starter_code"
        case functionSignature = "function_signature"
        case possibleSolution = "possible_solution"
        case showFunctionSignatureInStatement = "show_function_signature_in_statement"
        case availableProgrammingLanguageIDs = "available_programming_language_ids"
    }
}

/// Typed game details returned by the question library.
public nonisolated struct ScreenGameDetails: Decodable, Hashable, Sendable {
    public let availableProgrammingLanguageIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case availableProgrammingLanguageIDs = "available_programming_language_ids"
    }
}

/// Typed text details returned by the question library.
public nonisolated struct ScreenTextDetails: Decodable, Hashable, Sendable {
    public let evaluationMode: String?

    enum CodingKeys: String, CodingKey {
        case evaluationMode = "evaluation_mode"
    }
}

/// Typed file upload details returned by the question library.
public nonisolated struct ScreenFileUploadDetails: Decodable, Hashable, Sendable {
    public let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case downloadUrl = "download_url"
    }
}

/// Typed video details returned by the question library.
public nonisolated struct ScreenVideoDetails: Decodable, Hashable, Sendable {
    public let recordingMedia: String?

    enum CodingKeys: String, CodingKey {
        case recordingMedia = "recording_media"
    }
}

/// Typed project resource details returned by the question library.
public nonisolated struct ScreenProjectResourceDetails: Decodable, Hashable, Sendable {
    public let version: String?
    public let resourceID: String?

    enum CodingKeys: String, CodingKey {
        case version
        case resourceID = "resource_id"
    }
}

/// Typed project details returned by the question library.
public nonisolated struct ScreenProjectDetails: Decodable, Hashable, Sendable {
    public let environment: ScreenEnvironmentDetails?
    public let resources: [ScreenProjectResourceDetails]?
    public let aiAssistAdditionalInstructions: String?
    public let aiAssistAllowed: Bool?
    public let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case environment
        case resources
        case aiAssistAdditionalInstructions = "ai_assist_additional_instructions"
        case aiAssistAllowed = "ai_assist_allowed"
        case downloadUrl = "download_url"
    }
}

/// Typed question details returned by the question library.
public nonisolated struct ScreenQuestionDetails: Decodable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let version: Int?
    public let type: String?
    public let domain: String?
    public let difficulty: String?
    public let points: Int?
    public let title: [String: String]?
    public let statement: [String: String]?
    public let locales: [String]?
    public let skill: String?
    public let resources: [ScreenQuestionResourceDetails]?
    public let comment: String?
    public let evaluation: ScreenEvaluationDetails?
    public let durationSeconds: Int?
    public let creationTime: String?
    public let modificationTime: String?
    public let fromCoderPadQuestionBank: Bool?
    public let teamID: UUID?
    public let automaticallySelectable: Bool?
    public let mcqDetails: ScreenMCQDetails?
    public let codeDetails: ScreenCodeDetails?
    public let gameDetails: ScreenGameDetails?
    public let textDetails: ScreenTextDetails?
    public let fileUploadDetails: ScreenFileUploadDetails?
    public let videoDetails: ScreenVideoDetails?
    public let projectDetails: ScreenProjectDetails?

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case type
        case domain
        case difficulty
        case points
        case title
        case statement
        case locales
        case skill
        case resources
        case comment
        case evaluation
        case durationSeconds = "duration_seconds"
        case creationTime = "creation_time"
        case modificationTime = "modification_time"
        case fromCoderPadQuestionBank = "from_coderpad_question_bank"
        case teamID = "team_id"
        case automaticallySelectable = "automatically_selectable"
        case mcqDetails = "mcq_details"
        case codeDetails = "code_details"
        case gameDetails = "game_details"
        case textDetails = "text_details"
        case fileUploadDetails = "file_upload_details"
        case videoDetails = "video_details"
        case projectDetails = "project_details"
    }
}

/// An offset page of lightweight question summaries.
public nonisolated struct ScreenQuestionsPage: Decodable, Hashable, Sendable {
    public let questions: [ScreenQuestionSummary]
    public let pagination: ScreenQuestionPagination?

    enum CodingKeys: String, CodingKey {
        case questions
        case pagination
    }
}
