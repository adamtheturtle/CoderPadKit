//
//  CoderPadError.swift
//  CoderPadKit
//

import Foundation

/// A failure from the CoderPad API or its transport.
///
/// The library deliberately keeps this type presentation-free and locale-free: it
/// carries the facts (the HTTP status and body, the underlying `URLError`, the decode
/// detail) without deciding how to phrase them for a user. Consumers that want
/// localized, user-facing sentences conform `CoderPadError` to `LocalizedError`
/// themselves, mapping the cases to their own copy and catalog.
///
/// The ``CoderPadClient`` retries idempotent GET requests on the transient cases
/// before surfacing one; see ``CoderPadClient``.
public nonisolated enum CoderPadError: Error, CustomStringConvertible, Sendable {
    /// No API key was configured for the request.
    case missingAPIKey
    /// The server returned a non-success HTTP status, with the response body.
    case http(Int, String)
    /// The response could not be decoded; the associated value is a short detail.
    case decode(String)
    /// A transport-level failure (offline, timeout, unreachable host) before any HTTP
    /// response arrived.
    case network(URLError)

    /// A concise, developer-facing description. This is intentionally not localized;
    /// see the type's discussion for user-facing presentation.
    public var description: String {
        switch self {
        case .missingAPIKey:
            "Missing API key."
        case let .http(code, body):
            "HTTP \(code): \(body)"
        case let .decode(detail):
            "Decode failed: \(detail)"
        case let .network(urlError):
            "Network error: \(urlError.localizedDescription)"
        }
    }

    /// Whether the failure is an authentication/authorization rejection (HTTP 401 or
    /// 403), which usually means the API key is missing, invalid, or lacks access.
    public var isUnauthorized: Bool {
        if case .http(401, _) = self { return true }
        if case .http(403, _) = self { return true }
        return false
    }
}
