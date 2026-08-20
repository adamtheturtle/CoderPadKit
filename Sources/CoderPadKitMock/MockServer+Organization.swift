//
//  MockServer+Organization.swift
//  CoderPadKit
//
//  Org directory, stats, and quota fixtures for the fake API. Split out of
//  MockServer.swift to keep each file within the line and body-length limits.
//

import Foundation

nonisolated extension MockFixtures {
    // The demo organization is an affectionate nod to Fawlty Towers: a Torquay
    // hotel whose staff somehow run a steady stream of interviews. The data stays
    // shaped like a real CoderPad org so every screen has believable content; the
    // names are just there to raise a smile.
    public static let orgName = "Fawlty Towers"
    static let orgDomain = "fawltytowers.co.uk"

    /// Injectable clock for rolling stats windows and quota reset dates. Tests override
    /// this to freeze "now"; production/demo leave it as wall-clock time (#194, #195).
    nonisolated(unsafe) static var now: () -> Date = { Date() }

    /// One interview team. Pads and people reference these by `id`, and the org
    /// payload lists them so the team filter can resolve ids to display names.
    static let teams: [(id: String, name: String)] = [
        ("team-frontdesk", "Front Desk"),
        ("team-dining", "Dining Room"),
        ("team-kitchen", "Kitchen"),
        ("team-housekeeping", "Housekeeping"),
        ("team-maintenance", "Maintenance")
    ]

    /// One demo org member. The two user-facing shapes (directory vs. stats) are
    /// projected from these below.
    private struct Person {
        let email: String
        let name: String
        let teamID: String
        let padsCreated: Int
    }

    /// Single source of truth for the demo org's members: the hotel's staff,
    /// ordered by how many pads they've run.
    private static let people: [Person] = [
        Person(email: "basil@fawltytowers.co.uk", name: "Basil Fawlty", teamID: "team-frontdesk", padsCreated: 41),
        Person(email: "sybil@fawltytowers.co.uk", name: "Sybil Fawlty", teamID: "team-frontdesk", padsCreated: 33),
        Person(email: "manuel@fawltytowers.co.uk", name: "Manuel", teamID: "team-dining", padsCreated: 27),
        Person(email: "terry@fawltytowers.co.uk", name: "Terry Hughes", teamID: "team-kitchen", padsCreated: 22),
        Person(email: "major@fawltytowers.co.uk", name: "Major Gowen", teamID: "team-frontdesk", padsCreated: 18),
        Person(email: "tibbs@fawltytowers.co.uk", name: "Miss Tibbs", teamID: "team-housekeeping", padsCreated: 14),
        Person(email: "gatsby@fawltytowers.co.uk", name: "Miss Gatsby", teamID: "team-housekeeping", padsCreated: 11),
        // The signed-in demo user, so "My Pads"/"My Questions" return real results.
        Person(email: demoUserEmail, name: demoUserName, teamID: "team-frontdesk", padsCreated: 8),
        Person(email: "oreilly@fawltytowers.co.uk", name: "Mr O'Reilly", teamID: "team-maintenance", padsCreated: 6),
        Person(email: "kurt@fawltytowers.co.uk", name: "Chef Kurt", teamID: "team-kitchen", padsCreated: 3),
        Person(email: "andre@fawltytowers.co.uk", name: "André", teamID: "team-dining", padsCreated: 0)
    ]

    /// Email and display name of the signed-in demo user - Polly, the one member of
    /// staff who reliably gets anything done. Kept here next to the org directory so
    /// the member, their pads, and their questions all line up.
    public static let demoUserEmail = "polly@fawltytowers.co.uk"
    public static let demoUserName = "Polly Sherman"

    /// The org's default language for omitted-language pad creation. Kept as a
    /// single source of truth alongside `organization()`'s `organization_default_language`,
    /// so `createPad` derives the same fallback the live API would.
    public static let organizationDefaultLanguage = "go"

    /// The demo org member's display name for `email`, or `nil` for an email
    /// outside the seeded directory (e.g. a pad's `owner_email` from a live-shaped
    /// but not seeded participant).
    static func personName(forEmail email: String) -> String? {
        people.first { $0.email == email }?.name
    }

    /// Directory shape: `/api/organization` and `/api/organization/users` return
    /// `{email, name, teams}` - no `pads_created`.
    static func users() -> [[String: Any]] {
        people.map { ["email": $0.email, "name": $0.name, "teams": [$0.teamID]] }
    }

    /// Stats shape: `/api/organization/stats` returns `{email, name, pads_created}`
    /// per user - no `teams`. Counts are derived from the same window as the aggregate.
    static func statsUsers(start: String, end: String) -> [[String: Any]] {
        let total = padsCreatedForWindow(start: start, end: end)
        let weights = people.map(\.padsCreated)
        let weightSum = max(weights.reduce(0, +), 1)
        var remaining = total
        return people.enumerated().map { index, person in
            let count: Int
            if index == people.count - 1 {
                count = remaining
            } else {
                count = total * person.padsCreated / weightSum
                remaining -= count
            }
            return ["email": person.email, "name": person.name, "pads_created": count]
        }
    }

    private static func teamPayload() -> [[String: Any]] {
        teams.map { ["id": $0.id, "name": $0.name] }
    }

    static func organization() -> [String: Any] {
        [
            "status": "OK",
            "id": 9999,
            "organization_name": orgName,
            "child_organizations": [],
            "user_count": users().count,
            "users": users(),
            // Deliberately not the New Pad/Question sheets' hardcoded "python3"
            // fallback, so the org-default pre-selection is visible in the demo.
            "organization_default_language": organizationDefaultLanguage,
            // SSO enabled with a portal URL so the Organization view's sign-on row
            // and "Open sign-in portal" action are exercised in the demo.
            "single_sign_on_supported": true,
            "single_sign_in_url": "https://app.coderpad.io/sso/fawlty-towers",
            "teams": teamPayload()
        ]
    }

    static func organizationStats(query: [String: String] = [:]) -> [String: Any] {
        let (start, end) = resolvedStatsWindow(query: query)
        return [
            "status": "OK",
            "start_time": start,
            "end_time": end,
            // Scale roughly with the requested window (~3 pads/day across the team)
            // so the picker produces a visibly different count.
            "pads_created": padsCreatedForWindow(start: start, end: end),
            "users": statsUsers(start: start, end: end)
        ]
    }

    /// Default window is the last seven days from ``now``, matching the live API
    /// contract and the client's documentation (#195).
    private static func resolvedStatsWindow(query: [String: String]) -> (String, String) {
        if let start = query["start_time"], let end = query["end_time"] {
            return (start, end)
        }
        let endDate = now()
        let startDate = endDate.addingTimeInterval(-7 * 86_400)
        return (iso8601(startDate), iso8601(endDate))
    }

    private static func padsCreatedForWindow(start: String, end: String) -> Int {
        guard let startDate = parseISO8601(start), let endDate = parseISO8601(end) else { return 21 }

        return min(900, max(1, Int(endDate.timeIntervalSince(startDate) / 86_400) * 3))
    }

    static func quota() -> [String: Any] {
        [
            "status": "OK",
            "trial_expires_at": "2027-01-01T00:00:00.000-08:00",
            "pads_used": 187,
            "quota_reset_at": iso8601(nextQuotaReset(from: now())),
            "unlimited": false,
            "overages_enabled": true,
            "pads_remaining": 313,
            "billing_cycle_pad_limit": 500
        ]
    }

    /// First day of the next calendar month after `date`, so the reset is always in
    /// the future for the current billing cycle (#194).
    private static func nextQuotaReset(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -7 * 3600) ?? .gmt
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else {
            return date.addingTimeInterval(30 * 86_400)
        }
        var next = DateComponents()
        next.year = month == 12 ? year + 1 : year
        next.month = month == 12 ? 1 : month + 1
        next.day = 1
        return calendar.date(from: next) ?? date.addingTimeInterval(30 * 86_400)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? basic.date(from: value)
    }
}
