//
//  Question.swift
//  CoderPadKit
//
//  The `Question` model, the normalized `InterviewType` / `PadState` value types,
//  the supporting question sub-models, and the `Pad` / `Question` conveniences that
//  depend on them.
//

import Foundation

/// A CoderPad question: a reusable interview prompt with optional starter code,
/// solution, test cases, and candidate instructions.
public nonisolated struct Question: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let ownerEmail: String
    public let language: String?
    public let description: String?
    public let shared: Bool?
    public let used: Int?
    public let takeHome: Bool?
    public let testCasesEnabled: Bool?
    public let solution: String?
    public let padType: String?
    public let isDraft: Bool?
    public let authorName: String?
    public let organizationName: String?
    /// Starter code inserted into the pad when this question is used.
    public let contents: String?
    /// Starter code variant used when the question runs against test cases.
    public let contentsForTestCases: String?
    public let publicTakeHomeSettingID: Int?
    public let customFiles: [QuestionCustomFile]
    public let testCases: [QuestionTestCase]
    public let createdAt: Date?
    public let updatedAt: Date?
    public let candidateInstructions: [CandidateInstruction]

    enum CodingKeys: String, CodingKey {
        case id, title, language, description, shared, used, solution, contents
        case ownerEmail = "owner_email"
        case takeHome = "take_home"
        case testCasesEnabled = "test_cases_enabled"
        case padType = "pad_type"
        case isDraft = "is_draft"
        case authorName = "author_name"
        case organizationName = "organization_name"
        case contentsForTestCases = "contents_for_test_cases"
        case publicTakeHomeSettingID = "public_take_home_setting_id"
        case customFiles = "custom_files"
        case testCases = "test_cases"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case candidateInstructions = "candidate_instructions"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = container.loggedDecodeIfPresent(String.self, forKey: .title) ?? ""
        ownerEmail = container.loggedDecodeIfPresent(String.self, forKey: .ownerEmail) ?? ""
        language = container.loggedDecodeIfPresent(String.self, forKey: .language)
        description = container.loggedDecodeIfPresent(String.self, forKey: .description)
        shared = container.loggedDecodeIfPresent(Bool.self, forKey: .shared)
        used = container.loggedDecodeIfPresent(Int.self, forKey: .used)
        takeHome = container.loggedDecodeIfPresent(Bool.self, forKey: .takeHome)
        testCasesEnabled = container.loggedDecodeIfPresent(Bool.self, forKey: .testCasesEnabled)
        solution = container.loggedDecodeIfPresent(String.self, forKey: .solution)
        padType = container.loggedDecodeIfPresent(String.self, forKey: .padType)
        isDraft = container.loggedDecodeIfPresent(Bool.self, forKey: .isDraft)
        authorName = container.loggedDecodeIfPresent(String.self, forKey: .authorName)
        organizationName = container.loggedDecodeIfPresent(String.self, forKey: .organizationName)
        contents = container.loggedDecodeIfPresent(String.self, forKey: .contents)
        contentsForTestCases = container.loggedDecodeIfPresent(String.self, forKey: .contentsForTestCases)
        publicTakeHomeSettingID = container.loggedDecodeIfPresent(Int.self, forKey: .publicTakeHomeSettingID)
        customFiles = container.loggedDecodeIfPresent([QuestionCustomFile].self, forKey: .customFiles) ?? []
        testCases = container.loggedDecodeIfPresent([QuestionTestCase].self, forKey: .testCases) ?? []
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
        candidateInstructions = container
            .loggedDecodeIfPresent([CandidateInstruction].self, forKey: .candidateInstructions) ?? []
    }
}

/// Whether a pad or question is a real-time **live** interview or an async
/// **take-home**. This is the pad's *format*, a different axis from ``PadState``
/// (its lifecycle); "live" here means live-vs-take-home, never "currently running".
/// CoderPad models this inconsistently across resources: pads expose a free-form
/// `type` string, while questions expose a `take_home` boolean (and, on newer
/// records, a `pad_type` string). ``InterviewType`` normalizes all of these so
/// callers can present one consistent notion of type.
public enum InterviewType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case live
    case takeHome = "take-home"

    public var id: String {
        rawValue
    }

    /// Normalize a raw pad `type` / `pad_type` string. Accepts the hyphen and
    /// underscore spellings the API has used. Returns `nil` for empty or
    /// unrecognized values so callers can decide how to treat unexpected data.
    public init?(rawType: String?) {
        switch rawType?.lowercased() {
        case "live": self = .live
        case "take-home", "take_home", "takehome": self = .takeHome
        default: return nil
        }
    }
}

/// A pad's lifecycle *state* — where it is in the interview's life (currently running,
/// finished, not yet started, deleted). This is a different axis from ``InterviewType``,
/// which is the pad's *format* (live vs take-home); a single pad has both. In
/// particular "live" is an ``InterviewType``, not a ``PadState``: a pad can be a live
/// interview that is ``PadState/pending`` (scheduled, not started) or ``PadState/ended``.
///
/// Normalized from the API's free-form `state` string. CoderPad reports states like
/// "started"/"ended"/"pending"; older or future records may use synonyms
/// ("running", "finished", "draft"). ``PadState`` folds the known spellings into typed
/// cases and preserves anything unrecognized as ``PadState/other(_:)``, so callers can
/// switch over states without scattering string literals. Like ``InterviewType`` it
/// round-trips through a stable lowercase `rawValue`, which keeps persistence
/// wire-compatible with snapshots that stored the raw state string.
public enum PadState: Hashable, Identifiable, Codable, RawRepresentable, Sendable {
    case active
    case ended
    case pending
    case deleted
    /// A state the package doesn't model explicitly; carries the raw API spelling so
    /// it still renders and round-trips.
    case other(String)

    /// Normalize a raw API `state` string, folding known synonyms into typed cases.
    ///
    /// Note the deliberate omission of `"live"` here: "live" is the vocabulary of
    /// ``InterviewType`` (a live vs take-home *format*), not of a pad's *lifecycle*.
    /// CoderPad never reports `state == "live"`, so mapping it here would only invite
    /// the two axes to be confused; an unexpected `"live"` state instead falls through
    /// to ``PadState/other(_:)`` like any other unrecognized value.
    public init(apiState raw: String) {
        switch raw.lowercased() {
        case "started", "active", "running": self = .active
        case "ended", "finished", "completed": self = .ended
        case "pending", "draft": self = .pending
        case "deleted": self = .deleted
        case let value: self = .other(value)
        }
    }

    /// Total over all strings (unrecognized values become ``PadState/other(_:)``
    /// rather than failing), so it also serves as the `Codable` decode path.
    public init?(rawValue: String) {
        self.init(apiState: rawValue)
    }

    /// Canonical lowercase spelling, used for persistence and filter identity.
    public var rawValue: String {
        switch self {
        case .active: "active"
        case .ended: "ended"
        case .pending: "pending"
        case .deleted: "deleted"
        case let .other(raw): raw
        }
    }

    public var id: String {
        rawValue
    }

    /// Whether the interview ran and finished. True only for ``PadState/ended`` -
    /// deliberately *not* ``PadState/deleted``, which is removal, not completion.
    public var isEnded: Bool {
        self == .ended
    }

    public init(from decoder: any Decoder) throws {
        try self.init(apiState: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension Pad {
    /// Live vs take-home, normalized from the API's free-form `type` string.
    /// `nil` when the pad reports no (or an unrecognized) type.
    public var interviewType: InterviewType? {
        InterviewType(rawType: type)
    }

    /// The pad's lifecycle state, normalized from the free-form `state` string.
    public var status: PadState {
        PadState(apiState: state)
    }
}

extension Question {
    /// Live vs take-home. Prefers the `pad_type` string when present, otherwise
    /// derives it from the `take_home` boolean, defaulting to `.live`, which is how
    /// the API treats an absent or false `take_home`.
    public var interviewType: InterviewType {
        InterviewType(rawType: padType) ?? (takeHome == true ? .takeHome : .live)
    }

    /// The question's page in the CoderPad web dashboard: the same `/questions/:id`
    /// link the web app uses. Unlike a pad (which carries an absolute `url` from the
    /// API), a question has no URL of its own, so it is built from the owning
    /// account's server URL. Always succeeds, so callers can gate Share / Copy URL on
    /// having a selected question rather than on a missing URL.
    public func webURL(baseURL: URL) -> URL {
        baseURL.appending(path: "questions/\(id)")
    }
}

/// A supplementary file attached to a question (downloadable by the candidate).
public nonisolated struct QuestionCustomFile: Codable, Hashable, Identifiable, Sendable {
    public let id: String?
    public let title: String?
    public let description: String?
    public let filename: String?
    public let filesize: String?
}

/// One test case for a question, with its arguments and expected return value.
public nonisolated struct QuestionTestCase: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let returnValue: String?
    public let visible: Bool?
    public let arguments: [String]?

    enum CodingKeys: String, CodingKey {
        case id, visible, arguments
        case returnValue = "return_value"
    }
}

/// One block of candidate-facing instructions for a question.
public nonisolated struct CandidateInstruction: Codable, Hashable, Sendable {
    public let instructions: String
    public let defaultVisible: Bool

    enum CodingKeys: String, CodingKey {
        case instructions
        case defaultVisible = "default_visible"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instructions = (try? container.decodeIfPresent(String.self, forKey: .instructions)) ?? ""
        defaultVisible = (try? container.decodeIfPresent(Bool.self, forKey: .defaultVisible)) ?? true
    }
}
