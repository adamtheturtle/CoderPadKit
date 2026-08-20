//
//  Requests.swift
//  CoderPadKit
//
//  Encode-only request bodies for the pad and question mutation endpoints.
//

import Foundation

/// The request body for modifying a pad (`PUT /api/pads/:id`). Only the non-nil
/// fields are sent. The official "Modify a pad" contract carries the pad ID solely in
/// the URL path and documents no `id` body parameter, so ``encode(to:)`` omits it; the
/// `id` property still exists for path construction and for decoding round trips.
public nonisolated struct PadUpdate: Codable, Sendable {
    public var id: String
    public var title: String?
    public var language: String?
    public var ownerEmail: String?
    public var notes: String?
    public var isPrivate: Bool?
    public var executionEnabled: Bool?
    /// Resets the pad's editor contents. The API warns this destroys the pad's
    /// history, so callers should confirm before sending. Mutually exclusive with
    /// `questionID`; sending both is rejected by the API.
    public var contents: String?
    /// Associates a question with the pad, mirroring "create from question" on the
    /// web. Mutually exclusive with `contents`.
    public var questionID: Int?
    /// Set to `true` to end the interview. Any other value is ignored by the API.
    public var ended: Bool?
    /// Set to `true` to delete the interview. Any other value is ignored by the API.
    public var deleted: Bool?

    public init(
        id: String, title: String? = nil, language: String? = nil, ownerEmail: String? = nil,
        notes: String? = nil, isPrivate: Bool? = nil, executionEnabled: Bool? = nil,
        contents: String? = nil, questionID: Int? = nil, ended: Bool? = nil, deleted: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.ownerEmail = ownerEmail
        self.notes = notes
        self.isPrivate = isPrivate
        self.executionEnabled = executionEnabled
        self.contents = contents
        self.questionID = questionID
        self.ended = ended
        self.deleted = deleted
    }

    enum CodingKeys: String, CodingKey {
        case id, title, language, notes, contents, ended, deleted
        case ownerEmail = "owner_email"
        case isPrivate = "private"
        case executionEnabled = "execution_enabled"
        case questionID = "question_id"
    }
}

/// A path and its UTF-8 text contents for a multi-file question mutation.
///
/// This is an encode-only request value. It is intentionally separate from
/// ``QuestionCustomFile``, which describes downloadable file metadata returned by
/// the API rather than starter-code files sent in a question mutation.
public nonisolated struct QuestionFileContent: Encodable, Sendable {
    /// Maximum number of structured files accepted by a single mutation. Unlike a ZIP
    /// upload, the structured path has no archive framing to bound it otherwise.
    public static let maximumFileCount = 200
    /// Maximum accepted size of one file's `contents`, measured as UTF-8 bytes (1 MiB).
    public static let maximumFileByteCount = 1024 * 1024
    /// Maximum accepted combined size of every file's `contents` in one mutation,
    /// measured as UTF-8 bytes (10 MiB).
    public static let maximumAggregateByteCount = 10 * 1024 * 1024

    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

/// The request body for creating a question. `title`, `language`, and ``fileContents``
/// are encoded under a `question` object to match the API's documented bracketed
/// parameters; the remaining fields are sent flat, as the API documents them.
/// Encode-only: these are never decoded.
public nonisolated struct QuestionCreate: Encodable, Sendable {
    public var title: String
    public var language: String?
    public var description: String?
    public var solution: String?
    /// Starter code inserted into the interview session when this question is used.
    /// Mutually exclusive with ``fileContents`` and a ZIP upload.
    public var contents: String?
    /// Path/content entries for a multi-file question. Mutually exclusive with
    /// ``contents`` and a ZIP upload.
    public var fileContents: [QuestionFileContent]?
    public var takeHome: Bool?
    public var padType: String?
    public var candidateInstructions: [CandidateInstructionPayload]?
    public var aiAssistCustomSystemPrompt: String?

    public init(
        title: String, language: String? = nil, description: String? = nil, solution: String? = nil,
        contents: String? = nil, fileContents: [QuestionFileContent]? = nil,
        takeHome: Bool? = nil, padType: String? = nil,
        candidateInstructions: [CandidateInstructionPayload]? = nil,
        aiAssistCustomSystemPrompt: String? = nil
    ) {
        self.title = title
        self.language = language
        self.description = description
        self.solution = solution
        self.contents = contents
        self.fileContents = fileContents
        self.takeHome = takeHome
        self.padType = padType
        self.candidateInstructions = candidateInstructions
        self.aiAssistCustomSystemPrompt = aiAssistCustomSystemPrompt
    }

    private enum CodingKeys: String, CodingKey {
        case description, solution, contents, question
        case takeHome = "take_home"
        case padType = "pad_type"
        case candidateInstructions = "candidate_instructions"
        case aiAssistCustomSystemPrompt = "ai_assist_custom_system_prompt"
    }

    private enum QuestionKeys: String, CodingKey {
        case title, language
        case fileContents = "file_contents"
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        try validateQuestionContents(contents: contents, fileContents: fileContents)
        let normalizedTitle = try validatedQuestionTitle(title)
        let normalizedFileContents = try validatedFileContents(fileContents)
        let normalizedCandidateInstructions = try validatedCandidateInstructions(candidateInstructions)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(solution, forKey: .solution)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(takeHome, forKey: .takeHome)
        try container.encodeIfPresent(padType, forKey: .padType)
        try container.encodeIfPresent(normalizedCandidateInstructions, forKey: .candidateInstructions)
        try container.encodeIfPresent(aiAssistCustomSystemPrompt, forKey: .aiAssistCustomSystemPrompt)
        var question = container.nestedContainer(keyedBy: QuestionKeys.self, forKey: .question)
        try question.encode(normalizedTitle, forKey: .title)
        try question.encodeIfPresent(language, forKey: .language)
        try question.encodeIfPresent(normalizedFileContents, forKey: .fileContents)
    }
}

/// The request body for modifying a question. Like ``QuestionCreate``,
/// `title`/`language` are nested under `question`. The official "Modify a question"
/// contract carries the question ID solely in the URL path and lists no `id` form
/// field, so ``encode(to:)`` omits it, matching the ZIP multipart variant. The `id`
/// property still exists for path construction. Encode-only.
public nonisolated struct QuestionUpdate: Encodable, Sendable {
    public var id: Int
    public var title: String?
    public var language: String?
    public var description: String?
    public var solution: String?
    /// Starter code inserted into the interview session when this question is used.
    /// Mutually exclusive with ``fileContents`` and a ZIP upload.
    public var contents: String?
    /// Replacement path/content entries for a multi-file question. Mutually exclusive
    /// with ``contents`` and a ZIP upload.
    public var fileContents: [QuestionFileContent]?
    public var takeHome: Bool?
    public var padType: String?
    public var candidateInstructions: [CandidateInstructionPayload]?
    public var aiAssistCustomSystemPrompt: String?

    public init(
        id: Int, title: String? = nil, language: String? = nil, description: String? = nil,
        solution: String? = nil, contents: String? = nil,
        fileContents: [QuestionFileContent]? = nil, takeHome: Bool? = nil,
        padType: String? = nil, candidateInstructions: [CandidateInstructionPayload]? = nil,
        aiAssistCustomSystemPrompt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.description = description
        self.solution = solution
        self.contents = contents
        self.fileContents = fileContents
        self.takeHome = takeHome
        self.padType = padType
        self.candidateInstructions = candidateInstructions
        self.aiAssistCustomSystemPrompt = aiAssistCustomSystemPrompt
    }

    private enum CodingKeys: String, CodingKey {
        case description, solution, contents, question
        case takeHome = "take_home"
        case padType = "pad_type"
        case candidateInstructions = "candidate_instructions"
        case aiAssistCustomSystemPrompt = "ai_assist_custom_system_prompt"
    }

    private enum QuestionKeys: String, CodingKey {
        case title, language
        case fileContents = "file_contents"
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        try validateQuestionContents(contents: contents, fileContents: fileContents)
        let normalizedTitle = try title.map(validatedQuestionTitle)
        let normalizedFileContents = try validatedFileContents(fileContents)
        let normalizedCandidateInstructions = try validatedCandidateInstructions(candidateInstructions)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(solution, forKey: .solution)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(takeHome, forKey: .takeHome)
        try container.encodeIfPresent(padType, forKey: .padType)
        try container.encodeIfPresent(normalizedCandidateInstructions, forKey: .candidateInstructions)
        try container.encodeIfPresent(aiAssistCustomSystemPrompt, forKey: .aiAssistCustomSystemPrompt)
        if normalizedTitle != nil || language != nil || normalizedFileContents != nil {
            var question = container.nestedContainer(keyedBy: QuestionKeys.self, forKey: .question)
            try question.encodeIfPresent(normalizedTitle, forKey: .title)
            try question.encodeIfPresent(language, forKey: .language)
            try question.encodeIfPresent(normalizedFileContents, forKey: .fileContents)
        }
    }
}

/// One block of candidate instructions, as sent in a create/update request body.
public nonisolated struct CandidateInstructionPayload: Codable, Sendable {
    /// Maximum accepted size of `instructions`, measured as UTF-8 bytes (64 KiB).
    public static let maximumByteCount = 64 * 1024

    public var instructions: String
    public var defaultVisible: Bool

    public init(instructions: String, defaultVisible: Bool) {
        self.instructions = instructions
        self.defaultVisible = defaultVisible
    }

    enum CodingKeys: String, CodingKey {
        case instructions
        case defaultVisible = "default_visible"
    }
}

/// The request body for creating a pad (`POST /api/pads/`).
public nonisolated struct PadCreate: Codable, Sendable {
    public var title: String?
    public var language: String?
    public var ownerEmail: String?
    public var contents: String?
    public var notes: String?
    public var isPrivate: Bool?
    public var executionEnabled: Bool?
    /// Question to seed the pad from. The API documents this as singular
    /// `question_id` on create (the plural `question_ids` is a response-only field).
    /// Mutually exclusive with `contents`.
    public var questionID: Int?
    /// Links the new pad to a specific team. Settable only by org owners; omit to
    /// use the account's default team.
    public var teamID: String?

    public init(
        title: String? = nil, language: String? = nil, ownerEmail: String? = nil,
        contents: String? = nil, notes: String? = nil, isPrivate: Bool? = nil,
        executionEnabled: Bool? = nil, questionID: Int? = nil, teamID: String? = nil
    ) {
        self.title = title
        self.language = language
        self.ownerEmail = ownerEmail
        self.contents = contents
        self.notes = notes
        self.isPrivate = isPrivate
        self.executionEnabled = executionEnabled
        self.questionID = questionID
        self.teamID = teamID
    }

    enum CodingKeys: String, CodingKey {
        case title, language, contents, notes
        case ownerEmail = "owner_email"
        case isPrivate = "private"
        case executionEnabled = "execution_enabled"
        case questionID = "question_id"
        case teamID = "team_id"
    }

    /// A pad seeded from a question: same title and language, with the question
    /// attached. `isPrivate` and `executionEnabled` are left `nil` so the account's
    /// configured defaults apply; pass them explicitly to override.
    public static func fromQuestion(_ question: Question) -> Self {
        Self(
            title: question.title,
            language: question.language,
            questionID: question.id
        )
    }
}

// MARK: - execution_enabled string quirk

/// Encodes the optional execution flag the way CoderPad's pad endpoints actually
/// expect it: as the JSON **string** `"true"`/`"false"`, not a JSON boolean.
///
/// This contradicts the published API docs, which document `execution_enabled` as a
/// boolean. A real boolean is accepted by the request but silently ignored: the pad
/// falls back to the account default, so a new pad comes back execution-disabled even
/// when `true` was sent. Sending the string form is what actually takes effect. `nil`
/// is omitted entirely.
private nonisolated func encodeExecutionEnabled<K: CodingKey>(
    _ value: Bool?,
    into container: inout KeyedEncodingContainer<K>,
    forKey key: K
) throws {
    try container.encodeIfPresent(value.map { $0 ? "true" : "false" }, forKey: key)
}

/// Decodes `execution_enabled` tolerantly, accepting either the string form we now
/// send or a plain boolean (older payloads / the published-docs shape).
///
/// Internal rather than file-private because every type that reads this key has to
/// use it: ``Pad`` is the type that reads back what ``PadCreate``/``PadUpdate`` wrote,
/// so a strict `Bool` decode there means the package cannot read its own writes.
nonisolated func decodeExecutionEnabled<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> Bool? {
    if let string = try? container.decode(String.self, forKey: key) {
        switch string {
        case "true": return true
        case "false": return false
        default:
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected execution_enabled to be the string 'true' or 'false'."
            )
        }
    }
    return try container.decodeIfPresent(Bool.self, forKey: key)
}

extension KeyedDecodingContainer {
    /// The tolerant `execution_enabled` decode in the logging, never-throwing style the
    /// response models use (see `loggedDecodeIfPresent`), so a response model can read
    /// back the string form the request bodies send without a strict `Bool` decode
    /// turning the flag into "unknown".
    nonisolated func loggedDecodeExecutionEnabled(forKey key: Key) -> Bool? {
        do {
            return try decodeExecutionEnabled(from: self, forKey: key)
        } catch {
            apiLogger.debug(
                """
                decode '\(key.stringValue)' as execution_enabled \
                failed: \(error.localizedDescription)
                """
            )
            return nil
        }
    }
}

extension PadCreate {
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        ownerEmail = try container.decodeIfPresent(String.self, forKey: .ownerEmail)
        contents = try container.decodeIfPresent(String.self, forKey: .contents)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
        executionEnabled = try decodeExecutionEnabled(from: container, forKey: .executionEnabled)
        questionID = try container.decodeIfPresent(Int.self, forKey: .questionID)
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        try validatePadContents(contents: contents, questionID: questionID)
        let normalizedOwnerEmail = try validatedPadOwnerEmail(ownerEmail)
        let normalizedTeamID = try validatedTeamID(teamID)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(normalizedOwnerEmail, forKey: .ownerEmail)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try encodeExecutionEnabled(executionEnabled, into: &container, forKey: .executionEnabled)
        try container.encodeIfPresent(questionID, forKey: .questionID)
        try container.encodeIfPresent(normalizedTeamID, forKey: .teamID)
    }
}

extension PadUpdate {
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        ownerEmail = try container.decodeIfPresent(String.self, forKey: .ownerEmail)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
        executionEnabled = try decodeExecutionEnabled(from: container, forKey: .executionEnabled)
        contents = try container.decodeIfPresent(String.self, forKey: .contents)
        questionID = try container.decodeIfPresent(Int.self, forKey: .questionID)
        ended = try container.decodeIfPresent(Bool.self, forKey: .ended)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        try validatePadContents(contents: contents, questionID: questionID)
        try validatePadLifecycleFlags(ended: ended, deleted: deleted)
        let normalizedOwnerEmail = try validatedPadOwnerEmail(ownerEmail)
        var container = encoder.container(keyedBy: CodingKeys.self)
        // `id` is intentionally omitted: see the type doc above. `CodingKeys` still
        // declares it so `init(from:)` can decode a round trip.
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(normalizedOwnerEmail, forKey: .ownerEmail)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try encodeExecutionEnabled(executionEnabled, into: &container, forKey: .executionEnabled)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(questionID, forKey: .questionID)
        try container.encodeIfPresent(ended, forKey: .ended)
        try container.encodeIfPresent(deleted, forKey: .deleted)
    }
}
