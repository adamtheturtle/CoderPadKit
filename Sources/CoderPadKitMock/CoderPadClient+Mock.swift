//
//  CoderPadClient+Mock.swift
//  CoderPadKit
//
//  The `mock(...)` factory that backs a `CoderPadClient` with the in-process fake API.
//

import CoderPadKit
import Foundation

extension CoderPadClient {
    /// A client backed by the in-process fake API (``MockServer``), for demo modes and
    /// tests with no network.
    ///
    /// Pass `unauthorized: true` for a client whose mock server answers 401 for every
    /// request, to exercise the "bad key" path. `key` selects the mock's per-client
    /// state store (see `MockState`): it defaults to "demo" so a single demo account
    /// shares one store, while tests can pass a unique key each so their mutations stay
    /// isolated and a suite can run in parallel.
    public static func mock(unauthorized: Bool = false, key: String = "demo") -> Self {
        Self(apiKey: key, session: MockServer.session(unauthorized: unauthorized))
    }
}
