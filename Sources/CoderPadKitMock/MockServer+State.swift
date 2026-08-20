//
//  MockServer+State.swift
//  CoderPadKit
//
//  Per-client mutable state for the fake API. The session edits (pads/questions
//  created, updated, deleted) are layered over the immutable seed data in
//  `MockFixtures`. Each API key gets its own `MockState` (see `MockStateRegistry`),
//  so the app's demo account and every test have an isolated store - letting the
//  test suite run in parallel without racing on shared pad/question counts.
//

import Foundation
import Synchronization

final nonisolated class MockState: @unchecked Sendable {
    /// Serializes access to the mutable collections below. Per-state rather than
    /// global, so requests to different keys never contend, while concurrent
    /// requests to the *same* state (the client fans pages out concurrently) stay
    /// correctly serialized. The `@unchecked Sendable` on the type vouches that
    /// every access to the collections happens under this lock.
    let lock = Mutex(())

    var createdPads: [[String: Any]] = []
    var updatedPads: [String: [String: Any]] = [:]
    var deletedPadIDs: Set<String> = []
    var createdQuestions: [[String: Any]] = []
    var updatedQuestions: [Int: [String: Any]] = [:]
    var deletedQuestionIDs: Set<Int> = []
    /// Environments minted for pads created in this session (#190).
    var createdEnvironments: [Int: [String: Any]] = [:]
    /// Events appended during this session (e.g. an `ended` event from a successful
    /// `endPad`), layered after the canned seed timeline for that pad id.
    var appendedPadEvents: [String: [[String: Any]]] = [:]

    /// Next free environment id above seeded fixtures and prior creations.
    func nextEnvironmentID() -> Int {
        let seedIDs = MockFixtures.seedPads().flatMap { pad -> [Int] in
            (pad["pad_environment_ids"] as? [Int]) ?? []
        }
        let createdIDs = Array(createdEnvironments.keys)
        return (seedIDs + createdIDs).max().map { $0 + 1 } ?? 1_000
    }

    /// Seed questions with this state's edits layered on and deletions removed.
    func allQuestions() -> [[String: Any]] {
        let merged = (MockFixtures.questions() + createdQuestions).map { question -> [String: Any] in
            guard let id = question["id"] as? Int, let updates = updatedQuestions[id] else { return question }

            var combined = question
            for (key, value) in updates where key != "id" {
                combined[key] = value
            }
            return combined
        }
        return merged.filter { question in
            guard let id = question["id"] as? Int else { return true }

            return !deletedQuestionIDs.contains(id)
        }
    }

    /// Seed and session-created pads with this state's edits layered on and
    /// deletions removed.
    func allPads() -> [[String: Any]] {
        func applyUpdates(_ pad: [String: Any]) -> [String: Any] {
            guard let id = pad["id"] as? String, let updates = updatedPads[id] else { return pad }

            var merged = pad
            for (key, value) in updates where key != "id" {
                merged[key] = value
            }
            return merged
        }
        // Both seed pads and pads created during the session need their `updatedPads`
        // overrides applied, otherwise ending/editing a freshly-created pad silently
        // no-ops while still returning HTTP 200.
        let base = MockFixtures.seedPads().map(applyUpdates)
        let created = createdPads.map(applyUpdates)
        return (base + created).filter { pad in
            guard let id = pad["id"] as? String else { return true }

            return !deletedPadIDs.contains(id)
        }
    }

    /// The canned seed timeline for `id` with this session's appended events (e.g.
    /// from a successful `endPad`) layered on after it.
    func events(forPad id: String) -> [[String: Any]] {
        MockFixtures.events(forPad: id) + (appendedPadEvents[id] ?? [])
    }

    /// Records a lifecycle event for `id`, appended after its canned/previously
    /// recorded timeline. Called when a pad mutation (e.g. ending a pad) succeeds.
    func appendPadEvent(forPad id: String, _ event: [String: Any]) {
        appendedPadEvents[id, default: []].append(event)
    }
}

/// Maps an API key to its `MockState`, creating one on first use. The app's demo
/// account uses the stable key "demo" (one shared store for the session); tests
/// pass a unique key each, so their mutations never collide.
nonisolated enum MockStateRegistry {
    private static let lock = Mutex([String: MockState]())

    static func state(forKey key: String) -> MockState {
        lock.withLock { registry in
            if let existing = registry[key] { return existing }
            let created = MockState()
            registry[key] = created
            return created
        }
    }
}
