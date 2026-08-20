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
    /// A structured file path was blank, absolute, used traversal, or was not a
    /// safe relative project path (#143).
    case invalidFilePath(String)
    /// Two structured files shared the same normalized path (#144).
    case duplicateFilePath(String)
    /// `takeHome` and `padType` described different interview formats (#145).
    case contradictoryTakeHomeAndPadType

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
        case let .invalidFilePath(path):
            "Question file path '\(path)' must be a nonempty relative project path."
        case let .duplicateFilePath(path):
            "Question file path '\(path)' is duplicated."
        case .contradictoryTakeHomeAndPadType:
            "takeHome and padType must describe the same interview format."
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
    /// `questionID` was present but not a positive Interview resource id (#146).
    case nonpositiveQuestionID

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
        case .nonpositiveQuestionID:
            "Pad question ID must be a positive integer when present."
        }
    }
}

nonisolated func validatePadContents(contents: String?, questionID: Int?) throws {
    guard contents == nil || questionID == nil else {
        throw PadMutationValidationError.mutuallyExclusiveContentsAndQuestion
    }
}

/// Requires a present question association id to be strictly positive (#146).
nonisolated func validatedPadQuestionID(_ questionID: Int?) throws -> Int? {
    guard let questionID else { return nil }
    guard questionID > 0 else {
        throw PadMutationValidationError.nonpositiveQuestionID
    }
    return questionID
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

/// Rejects a negative body ceiling so configuration can fail without trapping (#206).
nonisolated func validateNonNegativeResponseBodyLimit(_ bytes: Int) throws -> Int {
    guard bytes >= 0 else {
        throw CoderPadError.decode("Response limit must not be negative")
    }
    return bytes
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
/// reaches the encoder. Also normalizes and deduplicates paths (#143, #144).
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
    var seenPaths = Set<String>()
    var normalizedFiles: [QuestionFileContent] = []
    normalizedFiles.reserveCapacity(fileContents.count)
    for file in fileContents {
        let path = try validatedQuestionFilePath(file.path)
        guard seenPaths.insert(path).inserted else {
            throw QuestionMutationValidationError.duplicateFilePath(path)
        }
        let byteCount = file.contents.utf8.count
        guard byteCount <= QuestionFileContent.maximumFileByteCount else {
            throw QuestionMutationValidationError.fileContentTooLarge(
                path: path,
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
        normalizedFiles.append(QuestionFileContent(path: path, contents: file.contents))
    }
    return normalizedFiles
}

/// Requires a nonempty relative project path with no absolute roots, drive letters,
/// or `.` / `..` components (#143). Separators are normalized to `/`.
nonisolated func validatedQuestionFilePath(_ path: String) throws -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw QuestionMutationValidationError.invalidFilePath(path)
    }
    if trimmed.hasPrefix("/") || trimmed.hasPrefix("\\") {
        throw QuestionMutationValidationError.invalidFilePath(path)
    }
    // Windows drive / UNC roots such as `C:\main.py` or `\\server\share`.
    if trimmed.contains(":") || trimmed.contains("\\\\") {
        throw QuestionMutationValidationError.invalidFilePath(path)
    }
    let normalized = trimmed.replacingOccurrences(of: "\\", with: "/")
    let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        .map(String.init)
    guard !components.isEmpty,
          !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    else {
        throw QuestionMutationValidationError.invalidFilePath(path)
    }
    return components.joined(separator: "/")
}

/// Rejects contradictory `takeHome` / `padType` pairs when both are present and
/// `padType` maps to a known ``InterviewType`` (#145).
nonisolated func validateTakeHomePadType(takeHome: Bool?, padType: String?) throws {
    guard let takeHome, let padType else { return }
    guard let interviewType = InterviewType(rawType: padType) else { return }
    let implied: InterviewType = takeHome ? .takeHome : .live
    guard interviewType == implied else {
        throw QuestionMutationValidationError.contradictoryTakeHomeAndPadType
    }
}
