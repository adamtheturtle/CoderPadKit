//
//  RequestValidation.swift
//  CoderPadKit
//
//  Typed validation errors and the free functions that normalize and bound pad and
//  question mutation request bodies before they reach the encoder.
//

import Foundation

/// A question mutation selected incompatible sources for its starter content, or
/// supplied blank, nonprinting, or oversized text fields.
public nonisolated enum QuestionMutationValidationError: LocalizedError, Equatable, Sendable {
    /// More than one starter-content representation was supplied.
    case mutuallyExclusiveContentSources
    /// The title was empty after trimming whitespace, or contained a control or
    /// format character (NUL, other C0/C1 controls, bidi overrides, etc.).
    case blankOrControlTitle
    /// A candidate instructions block was empty after trimming whitespace, or
    /// contained a control or format character.
    case blankOrControlCandidateInstructions
    /// A candidate instructions block exceeded ``CandidateInstructionPayload/maximumByteCount``.
    case candidateInstructionsTooLarge(byteCount: Int, limit: Int)
    /// The structured file list exceeded ``QuestionFileContent/maximumFileCount``.
    case tooManyFileContents(count: Int, limit: Int)
    /// One file's contents exceeded ``QuestionFileContent/maximumFileByteCount``.
    case fileContentTooLarge(path: String, byteCount: Int, limit: Int)
    /// The combined size of every file's contents exceeded
    /// ``QuestionFileContent/maximumAggregateByteCount``.
    case fileContentsTooLarge(byteCount: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .mutuallyExclusiveContentSources:
            "Use only one of contents, structured file contents, or a question ZIP upload."
        case .blankOrControlTitle:
            "Question title must not be blank or contain control characters."
        case .blankOrControlCandidateInstructions:
            "Candidate instructions must not be blank or contain control characters."
        case let .candidateInstructionsTooLarge(byteCount, limit):
            "Candidate instructions are \(byteCount) bytes; the limit is \(limit) bytes."
        case let .tooManyFileContents(count, limit):
            "Question has \(count) structured files; the limit is \(limit) files."
        case let .fileContentTooLarge(path, byteCount, limit):
            "File '\(path)' is \(byteCount) bytes; the per-file limit is \(limit) bytes."
        case let .fileContentsTooLarge(byteCount, limit):
            "Structured file contents total \(byteCount) bytes; the limit is \(limit) bytes."
        }
    }
}

/// A pad mutation selected incompatible sources for its initial editor contents, sent
/// an implausible owner email or team ID, or set contradictory lifecycle flags.
public nonisolated enum PadMutationValidationError: LocalizedError, Equatable, Sendable {
    /// Both literal editor contents and a question were supplied.
    case mutuallyExclusiveContentsAndQuestion
    /// `ended` and `deleted` were both `true` in the same update.
    case endedAndDeletedTogether
    /// `ownerEmail` was present but not a plausible email address.
    case implausibleOwnerEmail
    /// `teamID` was present but not a canonical UUID.
    case invalidTeamID

    public var errorDescription: String? {
        switch self {
        case .mutuallyExclusiveContentsAndQuestion:
            "Use only one of contents or questionID when creating or updating a pad."
        case .endedAndDeletedTogether:
            "Use only one of ended or deleted; a pad cannot be ended and deleted together."
        case .implausibleOwnerEmail:
            "Pad owner email must be a plausible email address."
        case .invalidTeamID:
            "Pad team ID must be a canonical UUID."
        }
    }
}

nonisolated func validatePadContents(contents: String?, questionID: Int?) throws {
    guard contents == nil || questionID == nil else {
        throw PadMutationValidationError.mutuallyExclusiveContentsAndQuestion
    }
}

nonisolated func validatePadLifecycleFlags(ended: Bool?, deleted: Bool?) throws {
    guard !(ended == true && deleted == true) else {
        throw PadMutationValidationError.endedAndDeletedTogether
    }
}

/// The address trimmed and domain-lowercased via ``EmailValidation/normalized(_:)``,
/// then checked with ``EmailValidation/isPlausibleAddress(_:)``. `nil` passes through
/// unchanged: an absent owner email means "use the account default".
nonisolated func validatedPadOwnerEmail(_ ownerEmail: String?) throws -> String? {
    guard let ownerEmail else { return nil }
    let normalized = EmailValidation.normalized(ownerEmail)
    guard EmailValidation.isPlausibleAddress(normalized) else {
        throw PadMutationValidationError.implausibleOwnerEmail
    }
    return normalized
}

/// Requires a present `teamID` to be a canonical UUID, matching the official Interview
/// API's documented `team_id` type. `nil` passes through unchanged: an absent team ID
/// means "use the account's default team".
nonisolated func validatedTeamID(_ teamID: String?) throws -> String? {
    guard let teamID else { return nil }
    guard UUID(uuidString: teamID) != nil else {
        throw PadMutationValidationError.invalidTeamID
    }
    return teamID
}

nonisolated func validateQuestionContents(
    contents: String?, fileContents: [QuestionFileContent]?
) throws {
    guard contents == nil || fileContents == nil else {
        throw QuestionMutationValidationError.mutuallyExclusiveContentSources
    }
}

/// Trims surrounding whitespace and rejects text that is empty afterward or that
/// contains any control or format character (NUL, other C0/C1 controls, bidi
/// overrides, zero-width joiners, etc.) anywhere in the trimmed text.
private nonisolated func normalizedNonBlankText(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.unicodeScalars.contains(where: { scalar in
        let category = scalar.properties.generalCategory
        return category == .control || category == .format
    }) else {
        return nil
    }
    return trimmed
}

/// The normalized title for a question mutation. Used from both `QuestionCreate` and
/// `QuestionUpdate` JSON encoding (`Requests.swift`) and their multipart fields
/// (`MultipartFormData.swift`).
nonisolated func validatedQuestionTitle(_ title: String) throws -> String {
    guard let normalized = normalizedNonBlankText(title) else {
        throw QuestionMutationValidationError.blankOrControlTitle
    }
    return normalized
}

/// Normalized, size-checked candidate instructions. Used from both JSON encoding
/// (`Requests.swift`) and multipart fields (`MultipartFormData.swift`).
nonisolated func validatedCandidateInstructions(
    _ instructions: [CandidateInstructionPayload]?
) throws -> [CandidateInstructionPayload]? {
    guard let instructions else { return nil }
    return try instructions.map { payload in
        guard let normalized = normalizedNonBlankText(payload.instructions) else {
            throw QuestionMutationValidationError.blankOrControlCandidateInstructions
        }
        let byteCount = normalized.utf8.count
        guard byteCount <= CandidateInstructionPayload.maximumByteCount else {
            throw QuestionMutationValidationError.candidateInstructionsTooLarge(
                byteCount: byteCount,
                limit: CandidateInstructionPayload.maximumByteCount
            )
        }
        return CandidateInstructionPayload(instructions: normalized, defaultVisible: payload.defaultVisible)
    }
}

/// Bounds a structured file list by count, per-file size, and aggregate size before it
/// reaches the encoder. `fileContents` is otherwise passed through unchanged: paths and
/// contents are not normalized, only measured.
nonisolated func validatedFileContents(
    _ fileContents: [QuestionFileContent]?
) throws -> [QuestionFileContent]? {
    guard let fileContents else { return nil }
    guard fileContents.count <= QuestionFileContent.maximumFileCount else {
        throw QuestionMutationValidationError.tooManyFileContents(
            count: fileContents.count,
            limit: QuestionFileContent.maximumFileCount
        )
    }
    var aggregateByteCount = 0
    for file in fileContents {
        let byteCount = file.contents.utf8.count
        guard byteCount <= QuestionFileContent.maximumFileByteCount else {
            throw QuestionMutationValidationError.fileContentTooLarge(
                path: file.path,
                byteCount: byteCount,
                limit: QuestionFileContent.maximumFileByteCount
            )
        }
        let (nextAggregate, overflow) = aggregateByteCount.addingReportingOverflow(byteCount)
        aggregateByteCount = overflow ? Int.max : nextAggregate
        guard aggregateByteCount <= QuestionFileContent.maximumAggregateByteCount else {
            throw QuestionMutationValidationError.fileContentsTooLarge(
                byteCount: aggregateByteCount,
                limit: QuestionFileContent.maximumAggregateByteCount
            )
        }
    }
    return fileContents
}
