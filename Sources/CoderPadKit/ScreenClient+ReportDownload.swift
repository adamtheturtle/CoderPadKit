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
        let operationID = UUID()
        try await withTaskCancellationHandler {
            try await ScreenReportOperationLimiter.shared.acquire(id: operationID)
        } onCancel: {
            Task { await ScreenReportOperationLimiter.shared.cancel(id: operationID) }
        }
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
        }

        guard let http = response as? HTTPURLResponse else {
            throw CoderPadError.http(0, "No HTTP response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw CoderPadError.http(http.statusCode, try Self.reportErrorBody(at: fileURL))
        }

        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        guard Self.isAllowedReportSize(declared: http.expectedContentLength, actual: fileSize) else {
            throw CoderPadError.decode("The report is too large to open.")
        }

        return try (Data(contentsOf: fileURL), http)
    }

    nonisolated static func reportErrorBody(at fileURL: URL) throws -> String {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var body = Data()
            while body.count < maximumErrorBodyBytes {
                let remaining = maximumErrorBodyBytes - body.count
                guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else { break }
                body.append(chunk)
            }
            return String(bytes: body, encoding: .utf8) ?? ""
        } catch {
            throw CoderPadError.decode("The report error response body could not be read.")
        }
    }

    public nonisolated static func isAllowedReportSize(declared: Int64, actual: Int) -> Bool {
        let maximum = Int64(ScreenReportFiles.maxReportBytes)
        return actual >= 0 && Int64(actual) <= maximum
            && (declared < 0 || declared <= maximum)
    }
}
