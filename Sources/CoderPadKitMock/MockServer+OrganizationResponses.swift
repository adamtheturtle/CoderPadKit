//
//  MockServer+OrganizationResponses.swift
//  CoderPadKitMock
//
//  Organization, quota, and org-scoped list routes for the Interview mock.
//

import Foundation

nonisolated extension MockResponses {
    // MARK: - Organization routes

    static func organizationRoute(
        state: MockState,
        method: String,
        path: String,
        query: [String: String]
    ) -> (Int, Data)? {
        if method == "GET", path == "/api/quota" {
            return ok(MockFixtures.quota())
        }

        if method == "GET", path == "/api/organization" {
            return ok(MockFixtures.organization())
        }

        if method == "GET", path == "/api/organization/stats" {
            return ok(MockFixtures.organizationStats(query: query))
        }

        if method == "GET", path == "/api/organization/pads" {
            return listed(
                state.allPads(), query: query, path: "/api/organization/pads", key: "pads"
            )
        }

        if method == "GET", path == "/api/organization/questions" {
            return listed(
                state.allQuestions(), query: query,
                path: "/api/organization/questions", key: "questions"
            )
        }

        if method == "GET", path == "/api/organization/users" {
            let users = MockFixtures.users()
            if let email = query["email"] {
                return ok(["status": "OK", "users": users.filter { ($0["email"] as? String) == email }])
            }
            return ok(["status": "OK", "users": users])
        }

        return nil
    }

    /// A pad id no pad in this state already holds. Deleted ids stay reserved because
    /// the live API never recycles an id it has handed out.
    static func newPadID(state: MockState) -> String {
        let taken = Set(
            (MockFixtures.seedPads() + state.createdPads).compactMap { $0["id"] as? String }
        ).union(state.deletedPadIDs)
        for _ in 0 ..< 100 {
            let candidate = "DEMO\(Int.random(in: 1000 ... 9999))"
            if !taken.contains(candidate) { return candidate }
        }
        var counter = 0
        while taken.contains("DEMO\(counter)") { counter += 1 }
        return "DEMO\(counter)"
    }
}
