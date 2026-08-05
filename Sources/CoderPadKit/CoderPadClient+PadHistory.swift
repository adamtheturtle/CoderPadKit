//
//  CoderPadClient+PadHistory.swift
//  CoderPadKit
//

import Foundation
import PaginatedRESTClient

public extension CoderPadClient {
    /// Fetches and chronologically orders a pad file's editor history from Firebase.
    ///
    /// Pass the `history` value from ``PadEnvironmentFile``. The CoderPad API key is
    /// deliberately not sent to this external URL. The URL must match
    /// ``PadHistoryURLPolicy``; redirects remain on its initial origin. Successful
    /// response bodies are limited by ``maximumHistoryResponseBodyBytes``. A Firebase
    /// `null` response is returned as an empty history.
    func padHistory(historyURL: String) async throws -> PadHistory {
        guard PadHistoryURLPolicy.isAllowed(historyURL, accountBaseURL: baseURL),
              let url = URL(string: historyURL)
        else {
            throw CoderPadError.http(0, "Invalid history URL")
        }

        let request = RESTRequest(
            url: url,
            method: "GET",
            headers: ["Accept": "application/json"]
        )
        return try await historyRest.performWithRetry(PadHistory?.self, request: request) ?? PadHistory()
    }
}
