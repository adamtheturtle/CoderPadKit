import Foundation

/// Typed multiple choice input accepted when saving a question.
public nonisolated struct ScreenMCQInput: Encodable, Hashable, Sendable {
    public enum SelectionMode: String, Encodable, CaseIterable, Hashable, Sendable {
        case single = "SINGLE"
        case multiple = "MULTIPLE"
    }

    public var choices: [ScreenQuestionChoiceInput]?
    public var selectionMode: SelectionMode?
    public var randomizeChoices: Bool?

    public init(
        choices: [ScreenQuestionChoiceInput]? = nil,
        selectionMode: SelectionMode? = nil,
        randomizeChoices: Bool? = nil
    ) {
        self.choices = choices
        self.selectionMode = selectionMode
        self.randomizeChoices = randomizeChoices
    }

    enum CodingKeys: String, CodingKey {
        case choices
        case selectionMode = "selection_mode"
        case randomizeChoices = "randomize_choices"
    }
}

/// Typed text input accepted when saving a question.
public nonisolated struct ScreenTextInput: Encodable, Hashable, Sendable {
    public enum EvaluationMode: String, Encodable, CaseIterable, Hashable, Sendable {
        case manual = "MANUAL"
        case automatic = "AUTOMATIC"
    }

    public var evaluationMode: EvaluationMode?

    public init(
        evaluationMode: EvaluationMode? = nil
    ) {
        self.evaluationMode = evaluationMode
    }

    enum CodingKeys: String, CodingKey {
        case evaluationMode = "evaluation_mode"
    }
}

/// Typed video input accepted when saving a question.
public nonisolated struct ScreenVideoInput: Encodable, Hashable, Sendable {
    public enum RecordingMedia: String, Encodable, CaseIterable, Hashable, Sendable {
        case video = "VIDEO"
        case audio = "AUDIO"
    }

    public var recordingMedia: RecordingMedia?

    public init(
        recordingMedia: RecordingMedia? = nil
    ) {
        self.recordingMedia = recordingMedia
    }

    enum CodingKeys: String, CodingKey {
        case recordingMedia = "recording_media"
    }
}

/// Typed project resource input accepted when saving a question.
public nonisolated struct ScreenProjectResourceInput: Encodable, Hashable, Sendable {
    public var version: String?
    public var resourceID: String?

    public init(
        version: String? = nil,
        resourceID: String? = nil
    ) {
        self.version = version
        self.resourceID = resourceID
    }

    enum CodingKeys: String, CodingKey {
        case version
        case resourceID = "resource_id"
    }
}

/// Typed project input accepted when saving a question.
public nonisolated struct ScreenProjectInput: Encodable, Hashable, Sendable {
    public var environment: ScreenEnvironmentInput?
    public var resources: [ScreenProjectResourceInput]?
    public var aiAssistAdditionalInstructions: String?
    public var aiAssistAllowed: Bool?
    public var temporaryFileID: String?

    public init(
        environment: ScreenEnvironmentInput? = nil,
        resources: [ScreenProjectResourceInput]? = nil,
        aiAssistAdditionalInstructions: String? = nil,
        aiAssistAllowed: Bool? = nil,
        temporaryFileID: String? = nil
    ) {
        self.environment = environment
        self.resources = resources
        self.aiAssistAdditionalInstructions = aiAssistAdditionalInstructions
        self.aiAssistAllowed = aiAssistAllowed
        self.temporaryFileID = temporaryFileID
    }

    enum CodingKeys: String, CodingKey {
        case environment
        case resources
        case aiAssistAdditionalInstructions = "ai_assist_additional_instructions"
        case aiAssistAllowed = "ai_assist_allowed"
        case temporaryFileID = "temporary_file_id"
    }
}

/// Writable fields for creating or updating a Screen question.
public nonisolated struct ScreenQuestionSave: Encodable, Hashable, Sendable {
    public enum QuestionType: String, Encodable, CaseIterable, Hashable, Sendable {
        case mcq = "MCQ"
        case code = "CODE"
        case text = "TEXT"
        case fileUpload = "FILE_UPLOAD"
        case video = "VIDEO"
        case project = "PROJECT"
    }

    public enum Difficulty: String, Encodable, CaseIterable, Hashable, Sendable {
        case easy = "EASY"
        case medium = "MEDIUM"
        case hard = "HARD"
    }

    public var type: QuestionType
    public var domain: String?
    public var durationSeconds: Int?
    public var difficulty: Difficulty?
    public var points: Int?
    public var title: [String: String]?
    public var statement: [String: String]?
    public var locales: [String]?
    public var skill: String?
    public var teamID: UUID?
    public var automaticallySelectable: Bool?
    public var comment: String?
    public var evaluation: ScreenEvaluationInput?
    public var codeDetails: ScreenCodeInput?
    public var mcqDetails: ScreenMCQInput?
    public var textDetails: ScreenTextInput?
    public var videoDetails: ScreenVideoInput?
    public var projectDetails: ScreenProjectInput?

    public init(
        type: QuestionType,
        domain: String? = nil,
        durationSeconds: Int? = nil,
        difficulty: Difficulty? = nil,
        points: Int? = nil,
        title: [String: String]? = nil,
        statement: [String: String]? = nil,
        locales: [String]? = nil,
        skill: String? = nil,
        teamID: UUID? = nil,
        automaticallySelectable: Bool? = nil,
        comment: String? = nil,
        evaluation: ScreenEvaluationInput? = nil,
        codeDetails: ScreenCodeInput? = nil,
        mcqDetails: ScreenMCQInput? = nil,
        textDetails: ScreenTextInput? = nil,
        videoDetails: ScreenVideoInput? = nil,
        projectDetails: ScreenProjectInput? = nil
    ) {
        self.type = type
        self.domain = domain
        self.durationSeconds = durationSeconds
        self.difficulty = difficulty
        self.points = points
        self.title = title
        self.statement = statement
        self.locales = locales
        self.skill = skill
        self.teamID = teamID
        self.automaticallySelectable = automaticallySelectable
        self.comment = comment
        self.evaluation = evaluation
        self.codeDetails = codeDetails
        self.mcqDetails = mcqDetails
        self.textDetails = textDetails
        self.videoDetails = videoDetails
        self.projectDetails = projectDetails
    }

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case durationSeconds = "duration_seconds"
        case difficulty
        case points
        case title
        case statement
        case locales
        case skill
        case teamID = "team_id"
        case automaticallySelectable = "automatically_selectable"
        case comment
        case evaluation
        case codeDetails = "code_details"
        case mcqDetails = "mcq_details"
        case textDetails = "text_details"
        case videoDetails = "video_details"
        case projectDetails = "project_details"
    }
}

/// Optional filters and ordering for every question library page.
public nonisolated struct ScreenQuestionFilters: Encodable, Hashable, Sendable {
    public enum Difficulty: String, Encodable, CaseIterable, Hashable, Sendable {
        case easy = "EASY"
        case medium = "MEDIUM"
        case hard = "HARD"
    }

    public enum Product: String, Encodable, CaseIterable, Hashable, Sendable {
        case screen = "SCREEN"
        case qualify = "QUALIFY"
    }

    public enum Sort: String, Encodable, CaseIterable, Hashable, Sendable {
        case id = "id"
        case title = "title"
        case type = "type"
        case durationSeconds = "duration_seconds"
        case difficulty = "difficulty"
        case domain = "domain"
        case skill = "skill"
        case programmingLanguage = "programming_language"
        case modificationTime = "modification_time"
        case fromCoderPadQuestionBank = "from_coderpad_question_bank"
        case product = "product"
    }

    public enum Order: String, Encodable, CaseIterable, Hashable, Sendable {
        case asc
        case desc
    }

    public var type: String?
    public var durationSecondsMin: Int?
    public var durationSecondsMax: Int?
    public var difficulty: Difficulty?
    public var domain: String?
    public var skill: String?
    public var programmingLanguage: String?
    public var fromCoderPadQuestionBank: Bool?
    public var product: Product?
    public var sort: Sort?
    public var order: Order?

    public init(
        type: String? = nil,
        durationSecondsMin: Int? = nil,
        durationSecondsMax: Int? = nil,
        difficulty: Difficulty? = nil,
        domain: String? = nil,
        skill: String? = nil,
        programmingLanguage: String? = nil,
        fromCoderPadQuestionBank: Bool? = nil,
        product: Product? = nil,
        sort: Sort? = nil,
        order: Order? = nil
    ) {
        self.type = type
        self.durationSecondsMin = durationSecondsMin
        self.durationSecondsMax = durationSecondsMax
        self.difficulty = difficulty
        self.domain = domain
        self.skill = skill
        self.programmingLanguage = programmingLanguage
        self.fromCoderPadQuestionBank = fromCoderPadQuestionBank
        self.product = product
        self.sort = sort
        self.order = order
    }

    enum CodingKeys: String, CodingKey {
        case type
        case durationSecondsMin = "duration_seconds_min"
        case durationSecondsMax = "duration_seconds_max"
        case difficulty
        case domain
        case skill
        case programmingLanguage = "programming_language"
        case fromCoderPadQuestionBank = "from_coderpad_question_bank"
        case product
        case sort
        case order
    }
}
