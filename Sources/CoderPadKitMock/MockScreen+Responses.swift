//
//  MockScreen+Responses.swift
//  coderpad
//
//  The fake Screen API's request router and its per-resource handlers. Split out of
//  MockScreen.swift so each file stays within the line and body-length limits. Mirrors
//  MockResponses, but Screen returns top-level arrays (not `{ "pads": [...] }`-style
//  envelopes), 204s for its action endpoints, and PDF bytes for reports.
//

import CoderPadKit
import Foundation
import Synchronization

nonisolated enum MockScreenResponses {
    /// A canned response: a status, body bytes, and the `Content-Type` to send (JSON for
    /// most routes, `application/pdf` for the report download).
    struct Result {
        let status: Int
        let body: Data
        let contentType: String
    }

    /// All Screen endpoints live under this versioned prefix (see `ScreenClient`). The
    /// router requires it before matching (#137).
    private static let apiPrefix = "/assessment/api/v1.1"

    // Compile the fixed route grammar once. `respond` runs while the mock state's
    // lock is held, so compiling up to six regexes per request serialized every
    // concurrent demo Screen call behind expensive Foundation setup (#2114).
    private static let campaignSendRoute = regex(#"^/campaigns/(\d+)/actions/send/?$"#)
    static let testReportRoute = regex(#"^/tests/(\d+)/report/?$"#)
    static let testCancelRoute = regex(#"^/tests/(\d+)/actions/cancel/?$"#)
    static let testResendRoute = regex(#"^/tests/(\d+)/actions/resend/?$"#)
    static let testDetailRoute = regex(#"^/tests/(\d+)/?$"#)

    static func respond(
        state: MockScreenState,
        method: String,
        path: String,
        query: [String: String] = [:],
        body: Data? = nil
    ) -> Result {
        // Hold this state's lock so its mutable collections are never read or written by
        // two requests at once: `startLoading()` runs on the URL loading system's
        // background threads. Per-state, so different keys never contend.
        state.lock.withLock { _ in
            respondLocked(state: state, method: method, path: path, query: query, body: body)
        }
    }

    /// The request handler proper. Always invoked while `state.lock` is held, so it may
    /// touch the mutable state without further synchronization. Must not re-enter
    /// `respond` — `Mutex` is not reentrant.
    private static func respondLocked(
        state: MockScreenState,
        method: String,
        path: String,
        query: [String: String],
        body: Data?
    ) -> Result {
        // Paths that omit the versioned prefix must not be routed (#137).
        guard path.hasPrefix(apiPrefix) else {
            return json(404, ["code": "not_found", "message": "not handled by mock: \(method) \(path)"])
        }
        let route = String(path.dropFirst(apiPrefix.count))

        if let result = campaignRoute(state: state, method: method, route: route, body: body) {
            return result
        }
        if let result = testRoute(state: state, method: method, route: route, query: query) {
            return result
        }
        if let result = webhookRoute(state: state, method: method, route: route, body: body) {
            return result
        }
        return json(404, ["code": "not_found", "message": "not handled by mock: \(method) \(route)"])
    }

    // MARK: - Campaign routes

    private static func campaignRoute(
        state: MockScreenState,
        method: String,
        route: String,
        body: Data?
    ) -> Result? {
        if method == "POST",
           let id = match(route, campaignSendRoute),
           let campaignID = Int(id) {
            return sendInvitation(state: state, campaignID: campaignID, body: body)
        }

        if method == "GET", route == "/campaigns" || route == "/campaigns/" {
            return json(200, MockScreenFixtures.campaigns())
        }

        return nil
    }

    /// Creates a "waiting" session from the invitation body and returns the new test id
    /// and the candidate's link, matching `POST /campaigns/:id/actions/send`.
    private static func sendInvitation(state: MockScreenState, campaignID: Int, body: Data?) -> Result {
        guard let body,
              let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else {
            return malformedJSON()
        }
        // Wrong-typed invitation fields must 4xx before mutating state (#196).
        if let error = invitationFieldError(params, key: "candidate_email") {
            return error
        }
        if let error = invitationFieldError(params, key: "candidate_name") {
            return error
        }
        let candidateName = params["candidate_name"] as? String
        if let candidateName, candidateName.count > ScreenClient.maximumCandidateNameLength {
            return json(400, [
                "code": "CandidateNameTooLong",
                "message": "Candidate name exceeds \(ScreenClient.maximumCandidateNameLength) characters"
            ])
        }
        guard let campaign = MockScreenFixtures.campaigns()
            .first(where: { ($0["id"] as? Int) == campaignID })
        else {
            return json(400, [
                "code": "InvalidCampaignId",
                "message": "Campaign not found"
            ])
        }
        if campaign["archived"] as? Bool == true {
            return json(400, [
                "code": "InvalidCampaignId",
                "message": "Campaign is archived"
            ])
        }

        let id = state.nextTestID
        state.nextTestID += 1
        let testURL = "https://app.coderpad.io/screen/demo/tests/\(id)"

        var session: [String: Any] = [
            "id": id, "id_test": id, "status": "waiting", "campaign_id": campaignID,
            "product": "screen",
            "organization_id": "4143ca74-2f0e-4151-90d6-e1428739450b", "candidate_language": "en",
            "send_time": MockScreenFixtures.nowMillis(),
            "last_activity_time": MockScreenFixtures.nowMillis(),
            "url": "https://app.coderpad.io/screen/demo/dashboard/tests/\(id)",
            "test_url": testURL, "questions": []
        ]
        session["candidate_email"] = (params["candidate_email"] as? String) as Any? ?? NSNull()
        session["candidate_name"] = candidateName as Any? ?? NSNull()
        session["tags"] = (params["tags"] as? String).map(splitTags) ?? []
        state.createdTests.append(session)

        return json(200, ["id": id, "test_url": testURL])
    }

    /// Absent keys and JSON null are fine; any other non-string value is a client error.
    private static func invitationFieldError(_ params: [String: Any], key: String) -> Result? {
        guard let value = params[key], !(value is NSNull) else { return nil }
        guard value is String else {
            return json(400, ["code": "invalid_request", "message": "\(key) must be a string"])
        }
        return nil
    }

    // MARK: - Webhook routes

    private static func webhookRoute(
        state: MockScreenState,
        method: String,
        route: String,
        body: Data?
    ) -> Result? {
        guard route == "/webhook" || route == "/webhook/" else { return nil }

        switch method {
        case "GET":
            // Documented "no webhook configuration" response (#213). A configured
            // callback still returns 200 with a JSON body.
            guard let url = state.webhookURL else {
                return Result(
                    status: 404,
                    body: Data(#"{"code":"NotFound","message":"No webhook configuration"}"#.utf8),
                    contentType: "application/json"
                )
            }
            return json(200, ["url": url])

        case "POST":
            // The body is the URL as a bare JSON string, per the API contract.
            guard let body, let url = try? JSONDecoder().decode(String.self, from: body) else {
                return malformedJSON()
            }
            state.webhookURL = url
            return noContent()

        case "DELETE":
            state.webhookURL = nil
            return noContent()

        default:
            return nil
        }
    }

    // MARK: - Helpers

    static func json(_ status: Int, _ value: Any) -> Result {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]))
            ?? Data("{}".utf8)
        return Result(status: status, body: data, contentType: "application/json")
    }

    static func malformedJSON() -> Result {
        json(400, ["code": "invalid_json", "message": "Malformed JSON request body"])
    }

    /// The 204 No Content used by the action and webhook write endpoints.
    static func noContent() -> Result {
        Result(status: 204, body: Data(), contentType: "application/json")
    }

    /// Splits an invitation's comma-separated `tags` string into the array shape the
    /// session model exposes.
    private static func splitTags(_ tags: String) -> [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func match(_ path: String, _ regex: NSRegularExpression) -> String? {
        let range = NSRange(path.startIndex..., in: path)
        guard let match = regex.firstMatch(in: path, range: range),
              match.numberOfRanges >= 2,
              let captured = Range(match.range(at: 1), in: path) else { return nil }

        return String(path[captured])
    }

    static func regex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid built-in mock route: \(pattern)")
        }
    }
}
