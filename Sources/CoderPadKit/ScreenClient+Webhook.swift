//
//  ScreenClient+Webhook.swift
//  coderpad
//

import Foundation
import SafeURLKit

public extension ScreenClient {
    private nonisolated static let webhookPolicy = URLPolicy(
        allowedSchemes: ["https"],
        portRule: .any,
        maximumLength: 2048
    )

    /// The currently configured webhook URL, if any. `GET /webhook`.
    ///
    /// The Screen collection documents both 204 (no content) and 404 (no configuration)
    /// as successful "no URL" outcomes; those map to `nil` rather than an HTTP or decode
    /// error so the optional return type matches the endpoint contract (#213, #214).
    public nonisolated func webhookURL() async throws -> String? {
        let request = try authorizedRequest(path: "/webhook", method: "GET")
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await self.data(for: request)
        } catch let CoderPadError.http(status, _) where status == 404 {
            return nil
        }
        switch response.statusCode {
        case 204:
            return nil
        case 200:
            let config = try decode(WebhookConfig.self, from: data)
            return try Self.validatedWebhookURL(config.url)
        default:
            throw CoderPadError.http(
                response.statusCode,
                String(bytes: data, encoding: .utf8) ?? ""
            )
        }
    }

    /// Sets (replacing any existing) the webhook callback URL. `POST /webhook`.
    /// The request body is the URL as a bare JSON string, per the API contract.
    public nonisolated func setWebhookURL(_ url: String) async throws {
        guard let url = Self.normalizedWebhookURL(url) else {
            throw CoderPadError.decode("Screen webhook callback must be a public HTTPS URL.")
        }

        try await sendNoContent(method: "POST", path: "/webhook", body: url)
    }

    /// Removes the configured webhook. `DELETE /webhook`.
    public nonisolated func deleteWebhook() async throws {
        try await sendNoContent(method: "DELETE", path: "/webhook")
    }

    private nonisolated struct WebhookConfig: Decodable { let url: String? }

    public nonisolated static func normalizedWebhookURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return webhookPolicy.allows(trimmed) ? trimmed : nil
    }

    public nonisolated static func validatedWebhookURL(_ raw: String?) throws -> String? {
        guard let raw else { return nil }
        guard let normalized = normalizedWebhookURL(raw) else {
            throw CoderPadError.decode("Screen returned an invalid webhook callback URL.")
        }

        return normalized
    }
}
