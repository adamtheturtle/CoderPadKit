//
//  MockScreen+State.swift
//  coderpad
//
//  Per-client mutable state for the fake Screen API. Invitations sent, sessions
//  cancelled or deleted, and the webhook URL are layered over the immutable seed data
//  in `MockScreenFixtures`. Each `API-Key` gets its own `MockScreenState` (see
//  `MockScreenStateRegistry`) so the demo account and every test have an isolated store.
//

import CoderPadKit
import Foundation
import Synchronization

final nonisolated class MockScreenState: @unchecked Sendable {
    /// Serializes access to the mutable state below. Per-state rather than global, so
    /// requests to different keys never contend while concurrent requests to the same
    /// state stay serialized. The `@unchecked Sendable` vouches that every access to the
    /// stored properties happens under this lock.
    let lock = Mutex(())

    /// The configured webhook callback URL, or `nil` when none is set.
    var webhookURL: String?
    /// Sessions created during the session via `POST /campaigns/:id/actions/send`.
    var createdTests: [[String: Any]] = []
    /// Sessions whose status has been overridden to "cancelled".
    var cancelledTestIDs: Set<Int> = []
    /// Sessions removed via `DELETE /tests/:id`.
    var deletedTestIDs: Set<Int> = []
    /// The next id handed to an invitation-created session, above the seed id range.
    var nextTestID = 9000

    /// Seed and invitation-created sessions, with cancellations applied and deletions
    /// removed — the single source the test routes read.
    func allTests() -> [[String: Any]] {
        (MockScreenFixtures.tests() + createdTests).compactMap { test in
            guard let id = test["id"] as? Int else { return test }

            if deletedTestIDs.contains(id) { return nil }

            var session = test
            if cancelledTestIDs.contains(id) { session["status"] = "cancelled" }
            return session
        }
    }
}

/// Maps an `API-Key` to its `MockScreenState`, creating one on first use. The app's demo
/// account uses the stable key "demo" (one shared store for the session); tests can pass
/// a unique key each so their mutations never collide.
///
/// Retention is bounded (#138): least-recently-used keys are evicted past
/// ``maximumRetainedKeys``, and ``removeState(forKey:)`` drops a key explicitly.
nonisolated enum MockScreenStateRegistry {
    private struct Storage {
        var states: [String: MockScreenState] = [:]
        /// LRU order — least recently used at the front.
        var order: [String] = []
    }

    private static let lock = Mutex(Storage())

    /// Cap on concurrently retained per-key stores so long-lived hosts cannot grow
    /// without bound when each test uses a unique key (#138).
    static let maximumRetainedKeys = 256

    static func state(forKey key: String) -> MockScreenState {
        lock.withLock { storage in
            if let existing = storage.states[key] {
                touch(&storage, key: key)
                return existing
            }

            let created = MockScreenState()
            storage.states[key] = created
            storage.order.append(key)
            evictIfNeeded(&storage)
            return created
        }
    }

    static func removeState(forKey key: String) {
        lock.withLock { storage in
            storage.states.removeValue(forKey: key)
            storage.order.removeAll { $0 == key }
        }
    }

    static var retainedKeyCount: Int {
        lock.withLock { $0.states.count }
    }

    private static func touch(_ storage: inout Storage, key: String) {
        if let index = storage.order.firstIndex(of: key) {
            storage.order.remove(at: index)
        }
        storage.order.append(key)
    }

    private static func evictIfNeeded(_ storage: inout Storage) {
        while storage.order.count > maximumRetainedKeys {
            let evicted = storage.order.removeFirst()
            storage.states.removeValue(forKey: evicted)
        }
    }
}
