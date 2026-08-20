//
//  ScreenClient+ResponseData.swift
//  CoderPadKit
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

nonisolated extension ScreenClient {
    /// Runs a bounded request, mapping transport and HTTP failures onto CoderPadError.
    /// Idempotent GETs retry transient 408/429/5xx and connectivity failures (#160).
    @discardableResult
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withIdempotentGETRetry(method: request.httpMethod) {
            try await dataOnce(for: request)
        }
    }

    @discardableResult
    private func dataOnce(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #if canImport(FoundationNetworking)
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(
                    for: request,
                    delegate: ScreenRedirectDelegate(requestURL: request.url)
                )
            } catch let urlError as URLError {
                if urlError.code == .cancelled { throw CancellationError() }
                throw CoderPadError.network(urlError)
            }
            let (http, limit) = try responseMetadata(for: response)
            let isSuccess = (200 ..< 300).contains(http.statusCode)
            guard !isSuccess || data.count <= limit else {
                throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
            }
            guard isSuccess else {
                let boundedErrorData = Data(data.prefix(limit))
                throw CoderPadError.http(
                    http.statusCode,
                    String(decoding: boundedErrorData, as: UTF8.self)
                )
            }
            return (data, http)
        #else
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(
                for: request,
                delegate: ScreenRedirectDelegate(requestURL: request.url)
            )
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        }
        let (http, limit) = try responseMetadata(for: response)
        let isSuccess = (200 ..< 300).contains(http.statusCode)

        let data = try await responseBody(from: bytes, response: http, limit: limit, isSuccess: isSuccess)
        guard isSuccess else {
            throw CoderPadError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        return (data, http)
        #endif
    }

    #if !canImport(FoundationNetworking)
    private func responseBody(
        from bytes: URLSession.AsyncBytes,
        response: HTTPURLResponse,
        limit: Int,
        isSuccess: Bool
    ) async throws -> Data {
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(response.expectedContentLength), limit))
        }
        do {
            for try await byte in bytes {
                guard data.count < limit else {
                    if isSuccess {
                        throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
                    }
                    break
                }
                data.append(byte)
            }
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        }
        return data
    }
    #endif

    private func responseMetadata(for response: URLResponse) throws -> (HTTPURLResponse, Int) {
        guard let http = response as? HTTPURLResponse else {
            throw CoderPadError.http(0, "No HTTP response")
        }
        let isSuccess = (200 ..< 300).contains(http.statusCode)
        let limit = isSuccess ? maximumResponseBodyBytes : Self.maximumErrorBodyBytes
        if isSuccess, http.expectedContentLength > Int64(limit) {
            throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
        }
        return (http, limit)
    }

    /// Bounded exponential backoff for idempotent Screen GETs (and PDF report downloads).
    func withIdempotentGETRetry<T>(
        method: String?,
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        let normalizedMethod = (method ?? "GET").uppercased()
        guard normalizedMethod == "GET", maxAttempts > 0 else {
            return try await operation()
        }

        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                attempt += 1
                guard attempt < maxAttempts, CoderPadRetryPolicy.isTransient(error) else {
                    throw error
                }
                apiLogger.debug(
                    "Transient Screen GET failure; retry \(attempt)/\(maxAttempts - 1)"
                )
                try await Task.sleep(for: .seconds(CoderPadRetryPolicy.backoffDelay(retryNumber: attempt)))
            }
        }
    }
}
