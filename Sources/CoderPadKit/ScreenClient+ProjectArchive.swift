import Foundation

public nonisolated extension ScreenClient {
    /// Returns the project tar.gz bytes with the candidate's changes applied.
    /// Uses the configured response ceiling, transport timeouts, and normal task cancellation.
    /// Saving or extracting the archive is the caller's responsibility.
    func projectArchive(testID: Int, questionID: UUID) async throws -> Data {
        try Self.requirePositiveID(testID, kind: "test")
        let path = "/tests/\(testID)/questions/\(questionID.uuidString.lowercased())/project"
        let request = try authorizedRequest(path: path, method: "GET", accept: "application/gzip")
        return try await data(for: request).0
    }
}
