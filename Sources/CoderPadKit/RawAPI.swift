//
//  RawAPI.swift
//  CoderPadKit
//
//  A bounded raw-response escape hatch for adapters that must preserve the API's
//  exact JSON rather than decode it into CoderPadKit's typed models.
//

import Foundation

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

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await boundedData(for: request, limit: responseLimit)
        return CoderPadRawResponse(
            status: (response as? HTTPURLResponse)?.statusCode ?? 0,
            data: data
        )
    }

    private nonisolated func boundedData(
        for request: URLRequest,
        limit: Int
    ) async throws -> (Data, URLResponse) {
        #if os(Linux)
            let (data, response) = try await session.data(for: request)
            guard data.count <= limit else {
                throw CoderPadResponseTooLargeError(limit: limit)
            }
            return (data, response)
        #else
            let (bytes, response) = try await session.bytes(for: request)
            if response.expectedContentLength > Int64(limit) {
                throw CoderPadResponseTooLargeError(limit: limit)
            }

            var data = Data()
            if response.expectedContentLength > 0 {
                data.reserveCapacity(min(Int(response.expectedContentLength), limit))
            }
            for try await byte in bytes {
                guard data.count < limit else {
                    throw CoderPadResponseTooLargeError(limit: limit)
                }
                data.append(byte)
            }
            return (data, response)
        #endif
    }
}
