import Foundation

/// An uploaded archive reference for a Screen project question. Use the ID promptly when creating the question.
public nonisolated struct ScreenTemporaryFile: Decodable, Hashable, Sendable {
    public let id: String
}

public nonisolated extension ScreenClient {
    /// The service accepts at most 52,428,800 archive bytes.
    static let maximumTemporaryFileBytes = 52_428_800

    /// Sends original gzip archive bytes in one request, returning a temporary file ID.
    /// Permission failures use the normal HTTP error contract. Writes are never retried.
    func uploadTemporaryFile(_ archive: Data) async throws -> ScreenTemporaryFile {
        guard archive.count <= Self.maximumTemporaryFileBytes else {
            throw CoderPadError.decode("Screen project archives must not exceed 52,428,800 bytes.")
        }
        var request = try authorizedRequest(path: "/temporary-file", method: "POST")
        request.setValue("application/gzip", forHTTPHeaderField: "Content-Type")
        request.setValue(String(archive.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = archive
        return try await decode(ScreenTemporaryFile.self, from: data(for: request).0)
    }
}
