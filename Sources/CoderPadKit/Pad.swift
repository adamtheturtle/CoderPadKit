//
//  Pad.swift
//  CoderPadKit
//
//  The `Pad` model and its environment/event sub-models.
//

import Foundation

/// A CoderPad interview pad: one coding session, its participants, and its metadata.
public nonisolated struct Pad: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let state: String
    public let ownerEmail: String
    public let language: String?
    public let participants: [String]
    public let url: String
    public let playback: String?
    /// API URL for this pad's event log. Convenience field; `padEvents(padID:)`
    /// derives the same URL from `id`, so this is decoded only for fidelity.
    public let events: String?
    /// Private interviewer notes. Round-trips with `PadCreate`/`PadUpdate`.
    public let notes: String?
    /// URL of the pad's whiteboard drawing image, if any.
    public let drawing: String?
    /// Pad code contents (legacy single-file representation).
    public let contents: String?
    /// Firebase history URL for the pad.
    public let history: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let endedAt: Date?
    public let type: String?
    public let executionEnabled: Bool?
    public let isPrivate: Bool?
    public let activeEnvironmentID: Int?
    public let padEnvironmentIDs: [Int]
    /// The pad-level list of attached question ids. The detail loads questions via
    /// each environment's own `questionID`, so this isn't read for display, but it is
    /// the pad-level reflection of an attached question (exercised by the create/update
    /// linkage tests) and is reserved for a future "linked questions" navigation.
    public let questionIDs: [Int]
    public let team: PadTeam?

    enum CodingKeys: String, CodingKey {
        case id, title, state, language, participants, url, playback, type, team
        case notes, drawing, contents, history, events
        case ownerEmail = "owner_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case endedAt = "ended_at"
        case executionEnabled = "execution_enabled"
        case isPrivate = "private"
        case activeEnvironmentID = "active_environment_id"
        case padEnvironmentIDs = "pad_environment_ids"
        case questionIDs = "question_ids"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = container.loggedDecodeIfPresent(String.self, forKey: .title) ?? ""
        state = container.loggedDecodeIfPresent(String.self, forKey: .state) ?? "unknown"
        ownerEmail = container.loggedDecodeIfPresent(String.self, forKey: .ownerEmail) ?? ""
        language = container.loggedDecodeIfPresent(String.self, forKey: .language)
        // The live API can include `null` entries in `participants` (e.g. an
        // anonymous or not-yet-named guest), so decode as optional strings and
        // drop the nulls rather than letting one null fail the whole array.
        participants = (container.loggedDecodeIfPresent([String?].self, forKey: .participants) ?? [])
            .compactMap(\.self)
        url = container.loggedDecodeIfPresent(String.self, forKey: .url) ?? ""
        playback = container.loggedDecodeIfPresent(String.self, forKey: .playback)
        events = container.loggedDecodeIfPresent(String.self, forKey: .events)
        notes = container.loggedDecodeIfPresent(String.self, forKey: .notes)
        drawing = container.loggedDecodeIfPresent(String.self, forKey: .drawing)
        contents = container.loggedDecodeIfPresent(String.self, forKey: .contents)
        history = container.loggedDecodeIfPresent(String.self, forKey: .history)
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
        endedAt = container.loggedDecodeIfPresent(Date.self, forKey: .endedAt)
        type = container.loggedDecodeIfPresent(String.self, forKey: .type)
        executionEnabled = container.loggedDecodeIfPresent(Bool.self, forKey: .executionEnabled)
        isPrivate = container.loggedDecodeIfPresent(Bool.self, forKey: .isPrivate)
        activeEnvironmentID = container.loggedDecodeIfPresent(Int.self, forKey: .activeEnvironmentID)
        padEnvironmentIDs = container.loggedDecodeIfPresent([Int].self, forKey: .padEnvironmentIDs) ?? []
        questionIDs = container.loggedDecodeIfPresent([Int].self, forKey: .questionIDs) ?? []
        team = container.loggedDecodeIfPresent(PadTeam.self, forKey: .team)
    }
}

extension Pad {
    /// The `updatedAt` timestamp, but only when it carries information beyond the
    /// pad's end time. Ending a pad is itself a write, so for ended pads
    /// `updated_at` usually equals `ended_at` and surfacing both is redundant.
    /// Returns a value only when a later edit (notes, feedback) moved `updated_at`
    /// meaningfully past the end.
    public var informativeUpdatedAt: Date? {
        guard let updatedAt else { return nil }
        guard let endedAt else { return updatedAt }

        return updatedAt.timeIntervalSince(endedAt) > 60 ? updatedAt : nil
    }

    /// The pad's web URL, parsed from the API's `url` string.
    public var webURL: URL? {
        URL(string: url)
    }

    /// The session playback URL, when the pad has one.
    public var playbackURL: URL? {
        playback.flatMap(URL.init(string:))
    }

    /// Whether the interview has finished. Prefers the explicit `ended_at`
    /// timestamp, falling back to the reported ``status``.
    public var isEnded: Bool {
        endedAt != nil || status == .ended
    }
}

/// A team a pad belongs to.
public nonisolated struct PadTeam: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
}

/// One entry in a pad's event log: a join, a code run, a question being added, and so on.
public nonisolated struct PadEvent: Decodable, Identifiable, Hashable, Sendable {
    public var id: String {
        "\(createdAt?.timeIntervalSince1970 ?? 0)-\(kind)-\(userName ?? "")-\(message)"
    }

    public let message: String
    public let kind: String
    /// Event-specific context: the language run for `ran`, the question ID for
    /// `added_question`, "spectator" for a spectator `joined`, and so on.
    public let metadata: String?
    public let userName: String?
    public let userEmail: String?
    public let createdAt: Date?

    public init(
        message: String, kind: String, metadata: String? = nil,
        userName: String? = nil, userEmail: String? = nil, createdAt: Date? = nil
    ) {
        self.message = message
        self.kind = kind
        self.metadata = metadata
        self.userName = userName
        self.userEmail = userEmail
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case message, kind, metadata
        case userName = "user_name"
        case userEmail = "user_email"
        case createdAt = "created_at"
    }
}

/// One file within a pad environment. Single-file languages return one of these;
/// multi-file frameworks/projects return one per file in the project.
public nonisolated struct PadEnvironmentFile: Decodable, Hashable, Sendable {
    public let path: String?
    public let contents: String?
    public let history: String?
}

/// A single execution environment within a pad: a language, its files, and the
/// question (if any) it was seeded from.
public nonisolated struct PadEnvironment: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let padID: Int?
    public let questionID: Int?
    /// e.g. "examples/035-django-shopping-list" when seeded from a CoderPad example.
    public let exampleQuestionID: String?
    public let language: String?
    public let fileContents: [PadEnvironmentFile]
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, language
        case padID = "pad_id"
        case questionID = "question_id"
        case exampleQuestionID = "example_question_id"
        case fileContents = "file_contents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        padID = container.loggedDecodeIfPresent(Int.self, forKey: .padID)
        questionID = container.loggedDecodeIfPresent(Int.self, forKey: .questionID)
        exampleQuestionID = container.loggedDecodeIfPresent(String.self, forKey: .exampleQuestionID)
        language = container.loggedDecodeIfPresent(String.self, forKey: .language)
        fileContents = container.loggedDecodeIfPresent([PadEnvironmentFile].self, forKey: .fileContents) ?? []
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// The combined code across all files in the environment, for a simple preview.
    /// Multi-file projects are concatenated with a header per file path.
    public var contents: String? {
        let files = fileContents.compactMap { file -> String? in
            guard let body = file.contents, !body.isEmpty else { return nil }

            if fileContents.count > 1, let path = file.path, !path.isEmpty {
                return "// \(path)\n\(body)"
            }
            return body
        }
        return files.isEmpty ? nil : files.joined(separator: "\n\n")
    }
}
