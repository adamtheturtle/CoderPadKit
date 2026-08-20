//
//  RawAPI.swift
//  CoderPadKit
//
//  A bounded raw-response escape hatch for adapters that must preserve the API's
//  exact JSON rather than decode it into CoderPadKit's typed models.
//

import Foundation
import PaginatedRESTClient

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The uninterpreted result of a CoderPad Interview API request.
///
/// This is intended for protocol adapters and diagnostics. Most applications should
/// prefer ``CoderPadClient``'s typed endpoint methods.
public nonisolated struct CoderPadRawResponse: Sendable {
    public let status: Int
    public let data: Data

    public var isSuccessful: Bool {
        (200 ... 299).contains(status)
    }

    public var body: String {
        String(decoding: data, as: UTF8.self)
    }

    public init(status: Int, data: Data) {
        self.status = status
        self.data = data
    }
}

/// A raw API response exceeded the caller's explicit memory-safety limit.
public nonisolated struct CoderPadResponseTooLargeError: LocalizedError, Sendable {
    public let limit: Int

    public var errorDescription: String? {
        "Response exceeded the \(limit)-byte safety limit."
    }

    public init(limit: Int) {
        self.limit = limit
    }
}

extension CoderPadClient {
    /// Performs an authenticated request and returns the exact response bytes.
    ///
    /// Use this when an adapter needs fields that are deliberately not represented by
    /// the typed models, or must relay CoderPad's response without re-encoding it.
    /// `responseLimit` bounds the response in memory and is required so callers make
    /// that safety policy explicit. Query items already configured on `baseURL` come
    /// first, followed by the caller's items; duplicate names are preserved in that
    /// order, as are valueless (`?flag`) and explicitly empty (`?key=`) items.
    public nonisolated func rawRequest(
        method: String = "GET",
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        responseLimit: Int
    ) async throws -> CoderPadRawResponse {
        guard !apiKey.isEmpty else {
            throw CoderPadError.missingAPIKey
        }
        guard responseLimit > 0 else {
            throw CoderPadError.http(0, "responseLimit must be positive")
        }
        let method = try Self.validatedHTTPMethod(method)
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw CoderPadError.http(0, "Invalid URL")
        }

        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else {
            throw CoderPadError.http(0, "Invalid URL")
        }

        var headers = [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json"
        ]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }

        let request = RESTRequest(
            url: url,
            method: method,
            headers: headers,
            body: body
        )
        do {
            let response = try await URLSessionTransport(
                session: session,
                successResponseLimit: responseLimit,
                errorResponseLimit: responseLimit
            ).response(for: request)
            return CoderPadRawResponse(status: response.statusCode, data: response.data)
        } catch is RESTResponseTooLargeError {
            throw CoderPadResponseTooLargeError(limit: responseLimit)
        }
    }

    /// Requires a nonempty RFC 7230 `token` and returns it uppercased.
    ///
    /// Rejects empty strings, surrounding whitespace, and any character outside the
    /// `tchar` set — including CR/LF — so a caller cannot smuggle header lines through
    /// the method field (#204).
    nonisolated static func validatedHTTPMethod(_ method: String) throws -> String {
        let trimmed = method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == method else {
            throw CoderPadError.decode("HTTP method must be a nonempty RFC 7230 token.")
        }
        let isToken = trimmed.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "a" ... "z", "A" ... "Z", "0" ... "9",
                 "!", "#", "$", "%", "&", "'", "*", "+", "-", ".",
                 "^", "_", "`", "|", "~":
                true
            default:
                false
            }
        }
        guard isToken else {
            throw CoderPadError.decode("HTTP method must be a nonempty RFC 7230 token.")
        }
        return trimmed.uppercased()
    }
}
