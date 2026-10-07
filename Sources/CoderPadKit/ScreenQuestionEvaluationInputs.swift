import Foundation

/// Typed rubric criterion input accepted when saving a question.
public nonisolated struct ScreenRubricCriterionInput: Encodable, Hashable, Sendable {
    public enum ReviewMode: String, Encodable, CaseIterable, Hashable, Sendable {
        case humanOnly = "HUMAN_ONLY"
        case aiSuggestions = "AI_SUGGESTIONS"
        case aiGrading = "AI_GRADING"
    }

    public var label: [String: String]?
    public var skill: String?
    public var points: Int?
    public var weight: Int?
    public var reviewMode: ReviewMode?
    public var description: String?

    public init(
        label: [String: String]? = nil,
        skill: String? = nil,
        points: Int? = nil,
        weight: Int? = nil,
        reviewMode: ReviewMode? = nil,
        description: String? = nil
    ) {
        self.label = label
        self.skill = skill
        self.points = points
        self.weight = weight
        self.reviewMode = reviewMode
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case label
        case skill
        case points
        case weight
        case reviewMode = "review_mode"
        case description
    }
}

/// Typed rubric input accepted when saving a question.
public nonisolated struct ScreenRubricInput: Encodable, Hashable, Sendable {
    public var criteria: [ScreenRubricCriterionInput]?

    public init(
        criteria: [ScreenRubricCriterionInput]? = nil
    ) {
        self.criteria = criteria
    }

    enum CodingKeys: String, CodingKey {
        case criteria
    }
}

/// Typed validation code test case input accepted when saving a question.
public nonisolated struct ScreenValidationCodeTestCaseInput: Encodable, Hashable, Sendable {
    public var label: [String: String]?
    public var testIdentifier: String?
    public var skill: String?
    public var points: Int?
    public var weight: Int?
    public var difficulty: Int?
    public var contributesToScore: Bool?
    public var visibleToCandidate: Bool?

    public init(
        label: [String: String]? = nil,
        testIdentifier: String? = nil,
        skill: String? = nil,
        points: Int? = nil,
        weight: Int? = nil,
        difficulty: Int? = nil,
        contributesToScore: Bool? = nil,
        visibleToCandidate: Bool? = nil
    ) {
        self.label = label
        self.testIdentifier = testIdentifier
        self.skill = skill
        self.points = points
        self.weight = weight
        self.difficulty = difficulty
        self.contributesToScore = contributesToScore
        self.visibleToCandidate = visibleToCandidate
    }

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

/// Typed validation code input accepted when saving a question.
public nonisolated struct ScreenValidationCodeInput: Encodable, Hashable, Sendable {
    public var testCases: [ScreenValidationCodeTestCaseInput]?

    public init(
        testCases: [ScreenValidationCodeTestCaseInput]? = nil
    ) {
        self.testCases = testCases
    }

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// Typed input output test case input accepted when saving a question.
public nonisolated struct ScreenInputOutputTestCaseInput: Encodable, Hashable, Sendable {
    public var label: [String: String]?
    public var input: String?
    public var output: String?
    public var skill: String?
    public var points: Int?
    public var weight: Int?
    public var difficulty: Int?
    public var contributesToScore: Bool?
    public var visibleToCandidate: Bool?
    public var timeoutMSByProgrammingLanguageID: [String: Int]?

    public init(
        label: [String: String]? = nil,
        input: String? = nil,
        output: String? = nil,
        skill: String? = nil,
        points: Int? = nil,
        weight: Int? = nil,
        difficulty: Int? = nil,
        contributesToScore: Bool? = nil,
        visibleToCandidate: Bool? = nil,
        timeoutMSByProgrammingLanguageID: [String: Int]? = nil
    ) {
        self.label = label
        self.input = input
        self.output = output
        self.skill = skill
        self.points = points
        self.weight = weight
        self.difficulty = difficulty
        self.contributesToScore = contributesToScore
        self.visibleToCandidate = visibleToCandidate
        self.timeoutMSByProgrammingLanguageID = timeoutMSByProgrammingLanguageID
    }

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

/// Typed input output input accepted when saving a question.
public nonisolated struct ScreenInputOutputEvaluationInput: Encodable, Hashable, Sendable {
    public var testCases: [ScreenInputOutputTestCaseInput]?

    public init(
        testCases: [ScreenInputOutputTestCaseInput]? = nil
    ) {
        self.testCases = testCases
    }

    enum CodingKeys: String, CodingKey {
        case testCases = "test_cases"
    }
}

/// Typed query comparison rules input accepted when saving a question.
public nonisolated struct ScreenQueryComparisonRulesInput: Encodable, Hashable, Sendable {
    public var rowOrderMatters: Bool?
    public var columnOrderMatters: Bool?
    public var compareAllTables: Bool?

    public init(
        rowOrderMatters: Bool? = nil,
        columnOrderMatters: Bool? = nil,
        compareAllTables: Bool? = nil
    ) {
        self.rowOrderMatters = rowOrderMatters
        self.columnOrderMatters = columnOrderMatters
        self.compareAllTables = compareAllTables
    }

    enum CodingKeys: String, CodingKey {
        case rowOrderMatters = "row_order_matters"
        case columnOrderMatters = "column_order_matters"
        case compareAllTables = "compare_all_tables"
    }
}

/// Typed SQL query result comparison input accepted when saving a question.
public nonisolated struct ScreenSQLQueryResultComparisonInput: Encodable, Hashable, Sendable {
    public var referenceQuery: String?
    public var comparison: ScreenQueryComparisonRulesInput?

    public init(
        referenceQuery: String? = nil,
        comparison: ScreenQueryComparisonRulesInput? = nil
    ) {
        self.referenceQuery = referenceQuery
        self.comparison = comparison
    }

    enum CodingKeys: String, CodingKey {
        case referenceQuery = "reference_query"
        case comparison
    }
}

/// Typed evaluation accepted answer input accepted when saving a question.
public nonisolated struct ScreenEvaluationAcceptedAnswerInput: Encodable, Hashable, Sendable {
    public enum MatchType: String, Encodable, CaseIterable, Hashable, Sendable {
        case exact = "EXACT"
        case regex = "REGEX"
    }

    public var value: String?
    public var matchType: MatchType?

    public init(
        value: String? = nil,
        matchType: MatchType? = nil
    ) {
        self.value = value
        self.matchType = matchType
    }

    enum CodingKeys: String, CodingKey {
        case value
        case matchType = "match_type"
    }
}

/// Typed text answer matching input accepted when saving a question.
public nonisolated struct ScreenTextAnswerMatchingInput: Encodable, Hashable, Sendable {
    public var acceptedAnswers: [ScreenEvaluationAcceptedAnswerInput]?

    public init(
        acceptedAnswers: [ScreenEvaluationAcceptedAnswerInput]? = nil
    ) {
        self.acceptedAnswers = acceptedAnswers
    }

    enum CodingKeys: String, CodingKey {
        case acceptedAnswers = "accepted_answers"
    }
}

/// Typed choice selection input accepted when saving a question.
public nonisolated struct ScreenChoiceSelectionInput: Encodable, Hashable, Sendable {
    public var correctChoiceIndexes: [Int]?

    public init(
        correctChoiceIndexes: [Int]? = nil
    ) {
        self.correctChoiceIndexes = correctChoiceIndexes
    }

    enum CodingKeys: String, CodingKey {
        case correctChoiceIndexes = "correct_choice_indexes"
    }
}

/// Typed evaluation input accepted when saving a question.
public nonisolated struct ScreenEvaluationInput: Encodable, Hashable, Sendable {
    public var rubric: ScreenRubricInput?
    public var validationCode: ScreenValidationCodeInput?
    public var inputOutput: ScreenInputOutputEvaluationInput?
    public var sqlQueryResultComparison: ScreenSQLQueryResultComparisonInput?
    public var textAnswerMatching: ScreenTextAnswerMatchingInput?
    public var choiceSelection: ScreenChoiceSelectionInput?

    public init(
        rubric: ScreenRubricInput? = nil,
        validationCode: ScreenValidationCodeInput? = nil,
        inputOutput: ScreenInputOutputEvaluationInput? = nil,
        sqlQueryResultComparison: ScreenSQLQueryResultComparisonInput? = nil,
        textAnswerMatching: ScreenTextAnswerMatchingInput? = nil,
        choiceSelection: ScreenChoiceSelectionInput? = nil
    ) {
        self.rubric = rubric
        self.validationCode = validationCode
        self.inputOutput = inputOutput
        self.sqlQueryResultComparison = sqlQueryResultComparison
        self.textAnswerMatching = textAnswerMatching
        self.choiceSelection = choiceSelection
    }

    enum CodingKeys: String, CodingKey {
        case rubric
        case validationCode = "validation_code"
        case inputOutput = "input_output"
        case sqlQueryResultComparison = "sql_query_result_comparison"
        case textAnswerMatching = "text_answer_matching"
        case choiceSelection = "choice_selection"
    }
}

/// Typed environment input accepted when saving a question.
public nonisolated struct ScreenEnvironmentInput: Encodable, Hashable, Sendable {
    public var version: String?
    public var environmentID: String?

    public init(
        version: String? = nil,
        environmentID: String? = nil
    ) {
        self.version = version
        self.environmentID = environmentID
    }

    enum CodingKeys: String, CodingKey {
        case version
        case environmentID = "environment_id"
    }
}

/// Typed database engine input accepted when saving a question.
public nonisolated struct ScreenDatabaseEngineInput: Encodable, Hashable, Sendable {
    public var version: String?
    public var engineID: String?

    public init(
        version: String? = nil,
        engineID: String? = nil
    ) {
        self.version = version
        self.engineID = engineID
    }

    enum CodingKeys: String, CodingKey {
        case version
        case engineID = "engine_id"
    }
}

/// Typed function signature input accepted when saving a question.
public nonisolated struct ScreenFunctionSignatureInput: Encodable, Hashable, Sendable {
    public var name: String?
    public var parameters: [[String: JSONValue]]?
    public var returnType: [String: JSONValue]?

    public init(
        name: String? = nil,
        parameters: [[String: JSONValue]]? = nil,
        returnType: [String: JSONValue]? = nil
    ) {
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
    }

    enum CodingKeys: String, CodingKey {
        case name
        case parameters
        case returnType = "return_type"
    }
}

/// Typed possible solution input accepted when saving a question.
public nonisolated struct ScreenPossibleSolutionInput: Encodable, Hashable, Sendable {
    public var code: String?
    public var programmingLanguageID: String?

    public init(
        code: String? = nil,
        programmingLanguageID: String? = nil
    ) {
        self.code = code
        self.programmingLanguageID = programmingLanguageID
    }

    enum CodingKeys: String, CodingKey {
        case code
        case programmingLanguageID = "programming_language_id"
    }
}

/// Typed code input accepted when saving a question.
public nonisolated struct ScreenCodeInput: Encodable, Hashable, Sendable {
    public enum Mode: String, Encodable, CaseIterable, Hashable, Sendable {
        case singleLanguage = "SINGLE_LANGUAGE"
        case multiLanguage = "MULTI_LANGUAGE"
    }

    public var environment: ScreenEnvironmentInput?
    public var mode: Mode?
    public var programmingLanguageID: String?
    public var candidateTestCode: String?
    public var validatorCode: String?
    public var timeoutMS: Int?
    public var databaseEngine: ScreenDatabaseEngineInput?
    public var databaseSetupScript: String?
    public var starterCode: String?
    public var functionSignature: ScreenFunctionSignatureInput?
    public var possibleSolution: ScreenPossibleSolutionInput?
    public var showFunctionSignatureInStatement: Bool?

    public init(
        environment: ScreenEnvironmentInput? = nil,
        mode: Mode? = nil,
        programmingLanguageID: String? = nil,
        candidateTestCode: String? = nil,
        validatorCode: String? = nil,
        timeoutMS: Int? = nil,
        databaseEngine: ScreenDatabaseEngineInput? = nil,
        databaseSetupScript: String? = nil,
        starterCode: String? = nil,
        functionSignature: ScreenFunctionSignatureInput? = nil,
        possibleSolution: ScreenPossibleSolutionInput? = nil,
        showFunctionSignatureInStatement: Bool? = nil
    ) {
        self.environment = environment
        self.mode = mode
        self.programmingLanguageID = programmingLanguageID
        self.candidateTestCode = candidateTestCode
        self.validatorCode = validatorCode
        self.timeoutMS = timeoutMS
        self.databaseEngine = databaseEngine
        self.databaseSetupScript = databaseSetupScript
        self.starterCode = starterCode
        self.functionSignature = functionSignature
        self.possibleSolution = possibleSolution
        self.showFunctionSignatureInStatement = showFunctionSignatureInStatement
    }

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
    }
}

/// Typed question choice input accepted when saving a question.
public nonisolated struct ScreenQuestionChoiceInput: Encodable, Hashable, Sendable {
    public var label: [String: String]?

    public init(
        label: [String: String]? = nil
    ) {
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case label
    }
}
