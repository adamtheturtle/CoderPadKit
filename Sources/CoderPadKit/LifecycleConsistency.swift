//
//  LifecycleConsistency.swift
//  CoderPadKit
//

import Foundation

/// A contradiction between a record's own lifecycle timestamps, or between them and
/// the state it reports.
///
/// These are reported, never fatal. Rejecting the record instead means one pad with
/// a bad timestamp fails the whole page it arrived in — `PadsPage.pads` is a plain
/// `[Pad]` — and a user's list errors out over a discrepancy that does not impair
/// anything they were going to be shown. Ordinary clock skew between the writes of
/// `created_at` and `updated_at` is enough to produce one. This matches how the
/// decoders already treat malformed sub-elements: skip, count, and expose a
/// diagnostic rather than abort.
public nonisolated enum LifecycleInconsistency: String, Sendable, Hashable, CaseIterable {
    /// `updated_at` precedes `created_at`.
    case updatedBeforeCreated
    /// `ended_at` precedes `created_at`.
    case endedBeforeCreated
    /// `ended_at` is set on a record whose state is active or pending.
    case endedWhileActive

    public var describedProblem: String {
        switch self {
        case .updatedBeforeCreated: "updated_at precedes created_at"
        case .endedBeforeCreated: "ended_at precedes created_at"
        case .endedWhileActive: "ended_at is set on an active or pending state"
        }
    }
}

/// States that contradict a set `ended_at`.
private nonisolated let activeOrPendingStates: Set<String> = [
    "started", "active", "running", "pending", "draft"
]

nonisolated func computeLifecycleInconsistencies(
    createdAt: Date?,
    updatedAt: Date?,
    endedAt: Date?,
    state: String?
) -> [LifecycleInconsistency] {
    var problems: [LifecycleInconsistency] = []
    if let createdAt, let updatedAt, updatedAt < createdAt {
        problems.append(.updatedBeforeCreated)
    }
    if let createdAt, let endedAt, endedAt < createdAt {
        problems.append(.endedBeforeCreated)
    }
    if endedAt != nil, let state, activeOrPendingStates.contains(state.lowercased()) {
        problems.append(.endedWhileActive)
    }
    return problems
}

nonisolated func describeLifecycleInconsistencies(_ problems: [LifecycleInconsistency]) -> String? {
    guard !problems.isEmpty else { return nil }

    return "Inconsistent lifecycle data: \(problems.map(\.describedProblem).joined(separator: ", "))."
}

public extension Pad {
    /// Contradictions in this pad's own lifecycle data, if any. Present for
    /// diagnostics; the pad decodes and displays regardless.
    var lifecycleInconsistencies: [LifecycleInconsistency] {
        computeLifecycleInconsistencies(
            createdAt: createdAt, updatedAt: updatedAt, endedAt: endedAt, state: state
        )
    }

    /// A sentence describing this pad's lifecycle contradictions, or nil when it has
    /// none.
    var lifecycleDiagnostic: String? {
        describeLifecycleInconsistencies(lifecycleInconsistencies)
    }
}

public extension Question {
    /// Contradictions in this question's own lifecycle data, if any. A question has
    /// no end state, so only the created/updated ordering applies.
    var lifecycleInconsistencies: [LifecycleInconsistency] {
        computeLifecycleInconsistencies(
            createdAt: createdAt, updatedAt: updatedAt, endedAt: nil, state: nil
        )
    }

    /// A sentence describing this question's lifecycle contradictions, or nil when it
    /// has none.
    var lifecycleDiagnostic: String? {
        describeLifecycleInconsistencies(lifecycleInconsistencies)
    }
}
