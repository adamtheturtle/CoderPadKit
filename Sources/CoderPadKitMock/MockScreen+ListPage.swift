//
//  MockScreen+ListPage.swift
//  coderpad
//
//  `GET /tests` filtering and pagination for the fake Screen API (#132–#134).
//

import CoderPadKit
import Foundation

nonisolated extension MockScreenResponses {
    /// One page of sessions for `GET /tests`, honoring the `campaignId`/`product`/
    /// `candidateEmail` filters, the documented `from`/`to` send-time bounds, and
    /// `start`/`limit` offset pagination (default/max 50, #134).
    static func testsPage(state: MockScreenState, query: [String: String]) -> Result {
        var tests = state.allTests()
        if let campaignID = query["campaignId"].flatMap(Int.init) {
            tests = tests.filter { ($0["campaign_id"] as? Int) == campaignID }
        }
        if let product = query["product"]?.lowercased() {
            guard ScreenClient.allowedProductFilters.contains(product) else {
                return json(400, [
                    "code": "InvalidProduct",
                    "message": "product must be one of: screen, map"
                ])
            }
            tests = tests.filter { ($0["product"] as? String)?.lowercased() == product }
        }
        if let email = query["candidateEmail"] {
            tests = tests.filter { ($0["candidate_email"] as? String) == email }
        }
        // Live Screen v1.1 filters by send time, not last activity (#133).
        if let fromMillis = query["from"].flatMap(Int.init) {
            tests = tests.filter { sendMillis($0) >= fromMillis }
        }
        if let toMillis = query["to"].flatMap(Int.init) {
            tests = tests.filter { sendMillis($0) <= toMillis }
        }

        let limit: Int
        if let rawLimit = query["limit"] {
            guard let parsed = Int(rawLimit),
                  (1 ... ScreenClient.maximumPageSize).contains(parsed)
            else {
                return json(400, [
                    "code": "InvalidLimit",
                    "message": "limit must be between 1 and \(ScreenClient.maximumPageSize)"
                ])
            }
            limit = parsed
        } else {
            limit = ScreenClient.maximumPageSize
        }

        let total = tests.count
        let start = max(query["start"].flatMap(Int.init) ?? 0, 0)
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

    /// A session's send instant in epoch milliseconds for the documented `from`/`to`
    /// bounds (#133).
    static func sendMillis(_ test: [String: Any]) -> Int {
        (test["send_time"] as? Int) ?? 0
    }
}
