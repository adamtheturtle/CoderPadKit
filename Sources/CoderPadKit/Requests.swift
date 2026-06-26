//
//  Requests.swift
//  CoderPadKit
//
//  Encode-only request bodies for the pad and question mutation endpoints.
//

import Foundation

/// The request body for modifying a pad (`PUT /api/pads/:id`). Only the non-nil
/// fields are sent. The `id` travels in the URL path as well as the body.
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

/// The request body for creating a question. `title` and `language` are encoded
/// nested under a `question` object to match the API's documented `question[title]` /
/// `question[language]` parameters; the remaining fields are sent flat, as the API
/// documents them. Encode-only: these are never decoded.
public nonisolated struct QuestionCreate: Encodable, Sendable {
    public var title: String
    public var language: String?
    public var description: String?
    public var solution: String?
    /// Starter code inserted into the interview session when this question is used.
    public var contents: String?
    public var takeHome: Bool?
    public var padType: String?
    public var candidateInstructions: [CandidateInstructionPayload]?

    public init(
        title: String, language: String? = nil, description: String? = nil, solution: String? = nil,
        contents: String? = nil, takeHome: Bool? = nil, padType: String? = nil,
        candidateInstructions: [CandidateInstructionPayload]? = nil
    ) {
        self.title = title
        self.language = language
        self.description = description
        self.solution = solution
        self.contents = contents
        self.takeHome = takeHome
        self.padType = padType
        self.candidateInstructions = candidateInstructions
    }

    private enum CodingKeys: String, CodingKey {
        case description, solution, contents, question
        case takeHome = "take_home"
        case padType = "pad_type"
        case candidateInstructions = "candidate_instructions"
    }

    private enum QuestionKeys: String, CodingKey {
        case title, language
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(solution, forKey: .solution)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(takeHome, forKey: .takeHome)
        try container.encodeIfPresent(padType, forKey: .padType)
        try container.encodeIfPresent(candidateInstructions, forKey: .candidateInstructions)
        var question = container.nestedContainer(keyedBy: QuestionKeys.self, forKey: .question)
        try question.encode(title, forKey: .title)
        try question.encodeIfPresent(language, forKey: .language)
    }
}

/// The request body for modifying a question. Like ``QuestionCreate``,
/// `title`/`language` are nested under `question`. The `id` travels in the URL path;
/// it is also encoded flat here for parity with the create payload. Encode-only.
public nonisolated struct QuestionUpdate: Encodable, Sendable {
    public var id: Int
    public var title: String?
    public var language: String?
    public var description: String?
    public var solution: String?
    /// Starter code inserted into the interview session when this question is used.
    public var contents: String?
    public var takeHome: Bool?
    public var padType: String?
    public var candidateInstructions: [CandidateInstructionPayload]?

    public init(
        id: Int, title: String? = nil, language: String? = nil, description: String? = nil,
        solution: String? = nil, contents: String? = nil, takeHome: Bool? = nil,
        padType: String? = nil, candidateInstructions: [CandidateInstructionPayload]? = nil
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.description = description
        self.solution = solution
        self.contents = contents
        self.takeHome = takeHome
        self.padType = padType
        self.candidateInstructions = candidateInstructions
    }

    private enum CodingKeys: String, CodingKey {
        case id, description, solution, contents, question
        case takeHome = "take_home"
        case padType = "pad_type"
        case candidateInstructions = "candidate_instructions"
    }

    private enum QuestionKeys: String, CodingKey {
        case title, language
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(solution, forKey: .solution)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(takeHome, forKey: .takeHome)
        try container.encodeIfPresent(padType, forKey: .padType)
        try container.encodeIfPresent(candidateInstructions, forKey: .candidateInstructions)
        if title != nil || language != nil {
            var question = container.nestedContainer(keyedBy: QuestionKeys.self, forKey: .question)
            try question.encodeIfPresent(title, forKey: .title)
            try question.encodeIfPresent(language, forKey: .language)
        }
    }
}

/// One block of candidate instructions, as sent in a create/update request body.
public nonisolated struct CandidateInstructionPayload: Codable, Sendable {
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

    /// A pad seeded from a question: same title and language, with the question attached.
    public static func fromQuestion(_ question: Question) -> Self {
        Self(
            title: question.title,
            language: question.language,
            ownerEmail: nil,
            contents: nil,
            notes: nil,
            isPrivate: false,
            executionEnabled: true,
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
private nonisolated func decodeExecutionEnabled<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> Bool? {
    if let string = try? container.decode(String.self, forKey: key) { return string == "true" }
    return try container.decodeIfPresent(Bool.self, forKey: key)
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
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(ownerEmail, forKey: .ownerEmail)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try encodeExecutionEnabled(executionEnabled, into: &container, forKey: .executionEnabled)
        try container.encodeIfPresent(questionID, forKey: .questionID)
        try container.encodeIfPresent(teamID, forKey: .teamID)
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
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(ownerEmail, forKey: .ownerEmail)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try encodeExecutionEnabled(executionEnabled, into: &container, forKey: .executionEnabled)
        try container.encodeIfPresent(contents, forKey: .contents)
        try container.encodeIfPresent(questionID, forKey: .questionID)
        try container.encodeIfPresent(ended, forKey: .ended)
        try container.encodeIfPresent(deleted, forKey: .deleted)
    }
}
