//
//  ScreenClient+ReportDownload.swift
//  coderpad
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension ScreenClient {
    /// Downloads report bytes to URLSession's temporary file, checking both the
    /// advertised and actual size before materializing the PDF in memory (#2767).
    public nonisolated func reportData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withIdempotentGETRetry(method: request.httpMethod) {
            try await reportDataOnce(for: request)
        }
    }

    private nonisolated func reportDataOnce(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let operationID = UUID()
        try await ScreenReportOperationLimiter.shared.acquire(id: operationID)
        defer { Task { await ScreenReportOperationLimiter.shared.release() } }

        let fileURL: URL
        let response: URLResponse
        do {
            (fileURL, response) = try await session.download(
                for: request,
                delegate: ScreenRedirectDelegate(requestURL: request.url)
            )
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        } catch is CancellationError {
            throw CancellationError()
        }

        guard let http = response as? HTTPURLResponse else {
            throw CoderPadError.http(0, "No HTTP response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            // Preserve the HTTP status even when the temporary error body cannot be
            // read, so callers still see `isUnauthorized` for 401/403 (#207).
            throw CoderPadError.http(http.statusCode, Self.reportErrorBody(at: fileURL))
        }

        return try (Self.reportSuccessData(at: fileURL, response: http), http)
    }

    /// Reads at most ``maximumErrorBodyBytes`` from a report error download. Unreadable
    /// files yield an empty body so the caller can still surface the HTTP status (#207).
    nonisolated static func reportErrorBody(at fileURL: URL) -> String {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var body = Data()
            while body.count < maximumErrorBodyBytes {
                let remaining = maximumErrorBodyBytes - body.count
                guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else { break }
                body.append(chunk)
            }
            return String(decoding: body, as: UTF8.self)
        } catch {
            return ""
        }
    }

    /// Loads a successful report file, mapping Cocoa I/O failures into ``CoderPadError``
    /// while preserving cancellation (#208).
    nonisolated static func reportSuccessData(at fileURL: URL, response: HTTPURLResponse) throws -> Data {
        do {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
            guard Self.isAllowedReportSize(declared: response.expectedContentLength, actual: fileSize) else {
                throw CoderPadError.decode("The report is too large to open.")
            }
            return try Data(contentsOf: fileURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CoderPadError {
            throw error
        } catch {
            throw CoderPadError.decode("The report response could not be read.")
        }
    }

    public nonisolated static func isAllowedReportSize(declared: Int64, actual: Int) -> Bool {
        let maximum = Int64(ScreenReportFiles.maxReportBytes)
        return actual >= 0 && Int64(actual) <= maximum
            && (declared < 0 || declared <= maximum)
    }
}
