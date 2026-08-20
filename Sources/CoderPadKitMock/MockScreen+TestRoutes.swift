//
//  MockScreen+TestRoutes.swift
//  coderpad
//
//  Test-session handlers for the Screen mock: list/detail, cancel/resend/delete, and
//  report export. Kept beside MockScreen+Responses so each type body stays within the
//  lint limit.
//

import CoderPadKit
import Foundation

nonisolated extension MockScreenResponses {
    // MARK: - Test-session routes

    static func testRoute(
        state: MockScreenState,
        method: String,
        route: String,
        query: [String: String]
    ) -> Result? {
        if method == "GET", let id = match(route, testReportRoute), let testID = Int(id) {
            return reportPDF(state: state, id: testID, query: query)
        }
        if method == "POST", let id = match(route, testCancelRoute), let testID = Int(id) {
            return cancelTest(state: state, id: testID)
        }
        if method == "POST", let id = match(route, testResendRoute), let testID = Int(id) {
            return resendTest(state: state, id: testID)
        }
        if method == "DELETE", let id = match(route, testDetailRoute), let testID = Int(id) {
            return deleteTest(state: state, id: testID)
        }
        if method == "GET", let id = match(route, testDetailRoute), let testID = Int(id) {
            return singleTest(state: state, id: testID, query: query)
        }
        if method == "GET", route == "/tests" || route == "/tests/" {
            return testsPage(state: state, query: query)
        }

        return nil
    }

    /// Cancels a waiting invitation only (#130, #135).
    private static func cancelTest(state: MockScreenState, id: Int) -> Result {
        guard let test = test(state: state, id: id) else { return notFoundTest() }
        guard (test["status"] as? String) == "waiting" else {
            return invalidTest("Only waiting invitations can be cancelled")
        }
        state.cancelledTestIDs.insert(id)
        return noContent()
    }

    /// Resends a waiting invitation only (#130, #135).
    private static func resendTest(state: MockScreenState, id: Int) -> Result {
        guard let test = test(state: state, id: id) else { return notFoundTest() }
        guard (test["status"] as? String) == "waiting" else {
            return invalidTest("Only waiting invitations can be resent")
        }
        return noContent()
    }

    /// Deletes an existing session (#130).
    private static func deleteTest(state: MockScreenState, id: Int) -> Result {
        guard test(state: state, id: id) != nil else { return notFoundTest() }
        state.deletedTestIDs.insert(id)
        return noContent()
    }

    /// One page of sessions for `GET /tests`, honoring the `campaignId`/`candidateEmail`/
    /// `product` filters, the `from`/`to` epoch-millisecond **send** bounds (#133), and
    /// `start`/`limit` offset pagination with the documented 1...50 limit (#134).
    private static func testsPage(state: MockScreenState, query: [String: String]) -> Result {
        var tests = state.allTests()
        if let campaignID = query["campaignId"].flatMap(Int.init) {
            tests = tests.filter { ($0["campaign_id"] as? Int) == campaignID }
        }
        if let email = query["candidateEmail"] {
            tests = tests.filter { ($0["candidate_email"] as? String) == email }
        }
        if let product = query["product"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !product.isEmpty {
            let normalized = product.lowercased()
            tests = tests.filter { ($0["product"] as? String)?.lowercased() == normalized }
        }
        // Live contract: `from`/`to` filter by when the session was sent (#133).
        if let fromMillis = query["from"].flatMap(Int.init) {
            tests = tests.filter { sendMillis($0) >= fromMillis }
        }
        if let toMillis = query["to"].flatMap(Int.init) {
            tests = tests.filter { sendMillis($0) <= toMillis }
        }

        let total = tests.count
        let start = max(query["start"].flatMap(Int.init) ?? 0, 0)
        let limit: Int
        if let rawLimit = query["limit"] {
            guard let parsed = Int(rawLimit),
                  (1 ... ScreenClient.maximumPageSize).contains(parsed) else {
                return json(400, [
                    "code": "InvalidParameter",
                    "message": "limit must be between 1 and \(ScreenClient.maximumPageSize)"
                ])
            }
            limit = parsed
        } else {
            limit = ScreenClient.maximumPageSize
        }
        let end: Int
        let (summed, overflow) = start.addingReportingOverflow(limit)
        if overflow {
            // A typed client should have rejected overflow-prone starts; still avoid
            // trapping if a raw query arrives with Int.max (#211).
            end = total
        } else {
            end = min(summed, total)
        }
        let window = start < end ? Array(tests[start ..< end]) : []
        let hasMore = end < total

        var pagination: [String: Any] = [
            "start": start, "limit": limit, "total": total, "has_more_items": hasMore
        ]
        if hasMore { pagination["next_start"] = end }
        return json(200, ["tests": window, "pagination": pagination])
    }

    /// A session's send instant in epoch milliseconds for the `from`/`to` bounds (#133).
    private static func sendMillis(_ test: [String: Any]) -> Int {
        (test["send_time"] as? Int) ?? 0
    }

    /// A single session for `GET /tests/:id`. Drops the report's community-score buckets
    /// unless `withCommunityStats=true`, mirroring the live API's opt-in field.
    private static func singleTest(state: MockScreenState, id: Int, query: [String: String]) -> Result {
        guard var test = test(state: state, id: id) else {
            return json(404, ["code": "not_found", "message": "test not found"])
        }

        if query["withCommunityStats"] != "true", var report = test["report"] as? [String: Any] {
            report["community_stats"] = nil
            test["report"] = report
        }
        return json(200, test)
    }

    /// The candidate's report as PDF bytes for `GET /tests/:id/report`, honoring export
    /// options (#131, #136).
    private static func reportPDF(state: MockScreenState, id: Int, query: [String: String]) -> Result {
        guard let test = test(state: state, id: id) else {
            return json(400, ["code": "NotFoundTestId", "message": "Test not found"])
        }
        guard let report = test["report"] as? [String: Any] else {
            return invalidTest("Report is not available for this test session")
        }

        let anonymous = boolQuery(query["anonymous"], default: false)
        let includeRank = boolQuery(query["include_rank"], default: true)
        let includeComparative = boolQuery(query["include_comparative_score"], default: true)
        let reportType = (query["report_type"] ?? ScreenReportType.full.rawValue).lowercased()

        let candidate: String?
        if anonymous {
            candidate = nil
        } else {
            candidate = (test["candidate_name"] as? String)
                ?? (test["candidate_email"] as? String) ?? "Candidate"
        }
        let score = report["score"] as? Double
        let comparative = includeComparative ? report["comparative_score"] as? Double : nil
        let rank = includeRank ? "Top \(Int((comparative ?? score ?? 0).rounded()))%" : nil
        let data = MockScreenFixtures.reportPDF(
            candidate: candidate,
            score: score,
            comparativeScore: comparative,
            rank: rank,
            reportType: reportType
        )
        return Result(status: 200, body: data, contentType: "application/pdf")
    }

    private static func test(state: MockScreenState, id: Int) -> [String: Any]? {
        state.allTests().first(where: { ($0["id"] as? Int) == id })
    }

    private static func notFoundTest() -> Result {
        json(400, ["code": "NotFoundTestId", "message": "Test not found"])
    }

    private static func invalidTest(_ message: String) -> Result {
        json(400, ["code": "InvalidTestId", "message": message])
    }

    private static func boolQuery(_ raw: String?, default defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        switch raw.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return defaultValue
        }
    }
}
