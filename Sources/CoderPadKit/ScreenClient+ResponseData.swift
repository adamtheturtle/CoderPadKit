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
    @discardableResult
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
        guard let http = response as? HTTPURLResponse else {
            throw CoderPadError.http(0, "No HTTP response")
        }
        let isSuccess = (200 ..< 300).contains(http.statusCode)
        let limit = isSuccess ? maximumResponseBodyBytes : Self.maximumErrorBodyBytes
        if isSuccess, http.expectedContentLength > Int64(limit) {
            throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
        }

        let data = try await responseBody(from: bytes, response: http, limit: limit, isSuccess: isSuccess)
        guard isSuccess else {
            throw CoderPadError.http(http.statusCode, String(bytes: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }

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
}
