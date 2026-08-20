//
//  MockScreen+TestActions.swift
//  coderpad
//
//  Cancel/resend/delete and report-export handlers for the fake Screen API
//  (#130, #131, #135, #136). Kept out of MockScreen+Responses so that file stays
//  within SwiftLint's type-body budget.
//

import CoderPadKit
import Foundation

nonisolated extension MockScreenResponses {
    /// Cancels a waiting invitation only (#130, #135).
    static func cancelTest(state: MockScreenState, id: Int) -> Result {
        guard let test = resolvedTest(state: state, id: id) else {
            return notFoundTest()
        }
        guard (test["status"] as? String) == "waiting" else {
            return invalidTestAction("Test cannot be cancelled in its current state")
        }
        state.cancelledTestIDs.insert(id)
        return noContent()
    }

    /// Resends a waiting invitation only (#130, #135).
    static func resendTest(state: MockScreenState, id: Int) -> Result {
        guard let test = resolvedTest(state: state, id: id) else {
            return notFoundTest()
        }
        guard (test["status"] as? String) == "waiting" else {
            return invalidTestAction("Test cannot be resent in its current state")
        }
        return noContent()
    }

    /// Deletes an existing session; unknown ids do not mutate state (#130).
    static func deleteTest(state: MockScreenState, id: Int) -> Result {
        guard resolvedTest(state: state, id: id) != nil else {
            return notFoundTest()
        }
        state.deletedTestIDs.insert(id)
        return noContent()
    }

    /// The candidate's report as PDF bytes for `GET /tests/:id/report`. Only finished
    /// sessions with report data can export (#131); query options affect the PDF (#136).
    static func reportPDF(state: MockScreenState, id: Int, query: [String: String]) -> Result {
        guard let test = resolvedTest(state: state, id: id) else {
            return notFoundTest()
        }
        guard let report = test["report"] as? [String: Any] else {
            return invalidTestAction("Report is only available after the candidate finishes")
        }

        let anonymous = query["anonymous"]?.lowercased() == "true"
        let candidate: String
        if anonymous {
            candidate = "Anonymous"
        } else {
            candidate = (test["candidate_name"] as? String)
                ?? (test["candidate_email"] as? String) ?? "Candidate"
        }
        let score = report["score"] as? Double
        let reportType = query["report_type"] ?? ScreenReportType.full.rawValue
        let includeRank = query["include_rank"]?.lowercased() == "true"
        let includeComparative = query["include_comparative_score"]?.lowercased() == "true"
        let comparative = includeComparative ? report["comparative_score"] as? Double : nil
        let data = MockScreenFixtures.reportPDF(
            candidate: candidate,
            score: score,
            reportType: reportType,
            includeRank: includeRank,
            comparativeScore: comparative
        )
        return Result(status: 200, body: data, contentType: "application/pdf")
    }

    static func resolvedTest(state: MockScreenState, id: Int) -> [String: Any]? {
        state.allTests().first(where: { ($0["id"] as? Int) == id })
    }

    static func notFoundTest() -> Result {
        json(404, ["code": "NotFoundTestId", "message": "test not found"])
    }

    static func invalidTestAction(_ message: String) -> Result {
        json(400, ["code": "InvalidTestId", "message": message])
    }
}
