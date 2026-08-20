//
//  ScreenClient+ReportDownload.swift
//  coderpad
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension ScreenClient {
    /// Streams report bytes while enforcing the 50 MiB success ceiling and the
    /// shared error-body limit as headers/bytes arrive (#110, #2767).
    nonisolated func reportData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withIdempotentGETRetry(method: request.httpMethod) {
            try await reportDataOnce(for: request)
        }
    }

    private nonisolated func reportDataOnce(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let operationID = UUID()
        try await ScreenReportOperationLimiter.shared.acquire(id: operationID)
        defer { Task { await ScreenReportOperationLimiter.shared.release() } }

        let (data, http) = try await boundedBody(
            for: request,
            successLimit: ScreenReportFiles.maxReportBytes,
            errorLimit: Self.maximumErrorBodyBytes
        )
        guard (200 ..< 300).contains(http.statusCode) else {
            // Preserve the HTTP status even when the body is empty/truncated, so
            // callers still see `isUnauthorized` for 401/403 (#207).
            throw CoderPadError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        guard Self.isAllowedReportSize(declared: http.expectedContentLength, actual: data.count) else {
            throw CoderPadError.decode("The report is too large to open.")
        }
        return (data, http)
    }

    /// Reads at most ``maximumErrorBodyBytes`` from a temporary report-error file.
    /// Unreadable files yield an empty body so the caller can still surface the
    /// HTTP status (#207). Kept for tests and residual file-backed paths.
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

    nonisolated static func isAllowedReportSize(declared: Int64, actual: Int) -> Bool {
        let maximum = Int64(ScreenReportFiles.maxReportBytes)
        return actual >= 0 && Int64(actual) <= maximum
            && (declared < 0 || declared <= maximum)
    }
}
