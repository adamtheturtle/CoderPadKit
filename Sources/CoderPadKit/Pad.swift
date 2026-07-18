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
    /// Whether access is limited to the pad's assigned interviewers.
    ///
    /// This field is present in live API responses but is not part of the
    /// published CoderPad Interview API contract.
    public let restrictInterviewerAccess: Bool?
    /// Interviewer-facing alerts recorded for the pad, such as suspicious
    /// candidate activity. Empirically observed; not in the published contract.
    public let padInterviewerNotifications: [PadInterviewerNotification]
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
        case restrictInterviewerAccess = "restrict_interviewer_access"
        case padInterviewerNotifications = "pad_interviewer_notifications"
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
        // The pad endpoints take `execution_enabled` as the JSON *string* "true"/"false"
        // (see `encodeExecutionEnabled`), and echo that back. Decode it tolerantly, as
        // `PadCreate`/`PadUpdate` do, so the package can read back what it writes.
        executionEnabled = container.loggedDecodeExecutionEnabled(forKey: .executionEnabled)
        isPrivate = container.loggedDecodeIfPresent(Bool.self, forKey: .isPrivate)
        restrictInterviewerAccess = container
            .loggedDecodeIfPresent(Bool.self, forKey: .restrictInterviewerAccess)
        padInterviewerNotifications = container
            .loggedDecodeIfPresent(
                [PadInterviewerNotification].self, forKey: .padInterviewerNotifications
            ) ?? []
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

/// An interviewer-facing alert recorded during a pad session.
///
/// CoderPadKit models this empirically observed live-response metadata even though
/// it is not currently described by the published CoderPad Interview API contract.
public nonisolated struct PadInterviewerNotification: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let message: String
    public let priority: Int?
    public let requestID: String?
    public let autoDismissed: Bool
    public let dismissedAt: Date?
    public let useful: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, message, priority, useful
        case requestID = "request_id"
        case autoDismissed = "auto_dismissed"
        case dismissedAt = "dismissed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = container.loggedDecodeIfPresent(String.self, forKey: .title) ?? ""
        message = container.loggedDecodeIfPresent(String.self, forKey: .message) ?? ""
        priority = container.loggedDecodeIfPresent(Int.self, forKey: .priority)
        requestID = container.loggedDecodeIfPresent(String.self, forKey: .requestID)
        autoDismissed = container.loggedDecodeIfPresent(Bool.self, forKey: .autoDismissed) ?? false
        dismissedAt = container.loggedDecodeIfPresent(Date.self, forKey: .dismissedAt)
        useful = container.loggedDecodeIfPresent(Bool.self, forKey: .useful)
        createdAt = container.loggedDecodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(Date.self, forKey: .updatedAt)
    }
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

/// One operation in a pad editor history entry.
///
/// CoderPad stores editor changes as an operational-transform sequence: positive
/// integers retain UTF-16 code units, negative integers delete them, and strings
/// insert text. The semantic cases below expose that compact wire format safely.
public nonisolated enum PadHistoryOperation: Hashable, Sendable {
    case retain(Int)
    case delete(Int)
    case insert(String)
}

extension PadHistoryOperation: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .insert(text)
            return
        }

        let count = try container.decode(Int.self)
        if count >= 0 {
            self = .retain(count)
        } else {
            guard count != .min else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "History delete count is out of range"
                )
            }
            self = .delete(-count)
        }
    }
}

/// One editor operation from a pad file's Firebase history.
public nonisolated struct PadHistoryEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let author: String
    public let operations: [PadHistoryOperation]
    /// Milliseconds since the Unix epoch, as supplied by Firebase.
    public let timestamp: Int64

    public init(id: String, author: String, operations: [PadHistoryOperation], timestamp: Int64) {
        self.id = id
        self.author = author
        self.operations = operations
        self.timestamp = timestamp
    }

    /// Applies this entry to the contents immediately preceding it.
    ///
    /// Counts operate on UTF-16 code units because the history is produced by the
    /// JavaScript editor. Oversized retains/deletes are clamped like string slicing,
    /// keeping malformed or truncated histories from crashing a replay.
    public func applying(to contents: String) -> String {
        let source = Array(contents.utf16)
        var cursor = 0
        var updated: [UInt16] = []

        for operation in operations {
            switch operation {
            case let .insert(text):
                updated.append(contentsOf: text.utf16)
            case let .retain(requested):
                let count = min(max(0, requested), source.count - cursor)
                updated.append(contentsOf: source[cursor ..< cursor + count])
                cursor += count
            case let .delete(requested):
                cursor += min(max(0, requested), source.count - cursor)
            }
        }
        updated.append(contentsOf: source[cursor...])
        return String(decoding: updated, as: UTF16.self)
    }
}

/// Chronologically ordered editor history for one pad file.
public nonisolated struct PadHistory: Decodable, Hashable, Sendable, RandomAccessCollection {
    public typealias Element = PadHistoryEntry
    public typealias Index = Array<PadHistoryEntry>.Index

    public let entries: [PadHistoryEntry]

    public init(entries: [PadHistoryEntry] = []) {
        self.entries = entries.sorted {
            ($0.timestamp, $0.id) < ($1.timestamp, $1.id)
        }
    }

    public var startIndex: Index { entries.startIndex }
    public var endIndex: Index { entries.endIndex }
    public subscript(position: Index) -> Element { entries[position] }
    public func index(after index: Index) -> Index { entries.index(after: index) }
    public func index(before index: Index) -> Index { entries.index(before: index) }

    private struct WireEntry: Decodable {
        let author: String
        let operations: [PadHistoryOperation]
        let timestamp: Int64

        enum CodingKeys: String, CodingKey {
            case author = "a"
            case operations = "o"
            case timestamp = "t"
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let values = try container.decode([String: WireEntry].self)
        self.init(entries: values.map { id, value in
            PadHistoryEntry(
                id: id,
                author: value.author,
                operations: value.operations,
                timestamp: value.timestamp
            )
        })
    }

    /// Replays every entry and returns the final file contents.
    public func replay(initialContents: String = "") -> String {
        entries.reduce(initialContents) { contents, entry in
            entry.applying(to: contents)
        }
    }
}

/// One file within a pad environment. Single-file languages return one of these;
/// multi-file frameworks/projects return one per file in the project.
public nonisolated struct PadEnvironmentFile: Decodable, Hashable, Sendable {
    public let path: String?
    public let contents: String?
    /// Firebase URL for this file's editor history, when history is available.
    public let history: String?
    /// Whether the file is binary. A binary file commonly has `nil` ``contents``;
    /// this empirically observed flag distinguishes that from an empty text file.
    public let binary: Bool?
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
