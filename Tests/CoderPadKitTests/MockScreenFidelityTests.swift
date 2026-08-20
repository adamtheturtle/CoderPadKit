//
//  MockScreenFidelityTests.swift
//  CoderPadKitTests
//
//  Live-shaped Screen mock behavior for invitations, actions, reports, filters,
//  and pagination (#129–#136).
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock Screen fidelity")
struct MockScreenFidelityTests {
    private func client(_ label: String = #function) -> ScreenClient {
        ScreenClient.mock(key: "screen-fidelity-\(label)-\(UUID().uuidString)")
    }

    // MARK: - #129 invitations

    @Test
    func `sendInvitation rejects an unknown campaign without mutating state`() async throws {
        let client = client()
        let before = try await client.listAllTests()

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.sendInvitation(
                campaignID: 999_999,
                ScreenInvitation(candidateEmail: "ghost@example.com")
            )
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 400)
        #expect(body.contains("InvalidCampaignId"))

        let after = try await client.listAllTests()
        #expect(before.map(\.id) == after.map(\.id))
    }

    @Test
    func `sendInvitation rejects an archived campaign`() async {
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client().sendInvitation(
                campaignID: 105,
                ScreenInvitation(candidateEmail: "ghost@example.com")
            )
        }
        guard case let .http(_, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(body.contains("InvalidCampaignId"))
    }

    // MARK: - #130 / #135 actions

    @Test
    func `cancel rejects an unknown test id`() async throws {
        let client = client()
        let before = try await client.listAllTests()
        let error = await #expect(throws: CoderPadError.self) {
            try await client.cancelTest(id: 999_999)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 404)
        #expect(body.contains("NotFoundTestId"))
        #expect(try await client.listAllTests().map(\.id) == before.map(\.id))
    }

    @Test
    func `resend rejects an unknown test id`() async {
        let error = await #expect(throws: CoderPadError.self) {
            try await client().resendTest(id: 999_999)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 404)
        #expect(body.contains("NotFoundTestId"))
    }

    @Test
    func `delete rejects an unknown test id without mutating state`() async throws {
        let client = client()
        let before = try await client.listAllTests()
        let error = await #expect(throws: CoderPadError.self) {
            try await client.deleteTest(id: 999_999)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 404)
        #expect(body.contains("NotFoundTestId"))
        #expect(try await client.listAllTests().map(\.id) == before.map(\.id))
    }

    @Test
    func `cancel rejects a completed session`() async throws {
        let client = client()
        let error = await #expect(throws: CoderPadError.self) {
            try await client.cancelTest(id: 5001)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 400)
        #expect(body.contains("InvalidTestId"))
        #expect(try await client.getTest(id: 5001).status == "completed")
    }

    @Test
    func `resend rejects a completed session`() async {
        let error = await #expect(throws: CoderPadError.self) {
            try await client().resendTest(id: 5001)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 400)
        #expect(body.contains("InvalidTestId"))
    }

    @Test
    func `cancel succeeds for a waiting invitation`() async throws {
        let client = client()
        try await client.cancelTest(id: 5004)
        let session = try await client.getTest(id: 5004)
        #expect(session.status == "cancelled")
    }

    // MARK: - #131 / #136 reports

    @Test
    func `report export rejects unfinished sessions`() async {
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client().testReport(id: 5004)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == 400)
        #expect(body.contains("InvalidTestId"))
    }

    @Test
    func `anonymous report export omits the candidate name`() async throws {
        let client = client()
        let named = try await client.testReport(id: 5001, anonymous: false)
        let anonymous = try await client.testReport(id: 5001, anonymous: true)

        #expect(containsPDFText(named, "candidate=Ada Lovelace"))
        #expect(!containsPDFText(anonymous, "candidate=Ada Lovelace"))
        #expect(containsPDFText(anonymous, "candidate=Anonymous"))
    }

    @Test
    func `report export honors report type and inclusion flags`() async throws {
        let data = try await client().testReport(
            id: 5001,
            reportType: .simplified,
            includeRank: true,
            includeComparativeScore: true
        )

        #expect(containsPDFText(data, "type=simplified"))
        #expect(containsPDFText(data, "rank=included"))
        #expect(containsPDFText(data, "comparative="))
    }

    // MARK: - #132 product filter

    @Test
    func `listTests filters by the documented product query`() async throws {
        let client = client()
        let screen = try await client.listAllTests(product: "screen")
        let map = try await client.listAllTests(product: "map")

        #expect(!screen.isEmpty)
        #expect(map.map(\.id) == [5401])
        #expect(Set(screen.map(\.id)).isDisjoint(with: Set(map.map(\.id))))
    }

    // MARK: - #133 send-time filter

    @Test
    func `listTests from and to filter by send time rather than activity`() async throws {
        let client = client()
        let ada = try await client.getTest(id: 5001)
        let send = try #require(ada.sendTime)
        let activity = try #require(ada.lastActivityTime)
        #expect(activity > send)

        // A window after send and around last activity must exclude Ada when filtering
        // by send time (the live contract), even though activity falls inside it.
        let page = try await client.listTests(
            from: send + 1,
            until: activity + 1,
            limit: ScreenClient.maximumPageSize
        )
        #expect(!page.tests.contains(where: { $0.id == 5001 }))
    }

    // MARK: - #134 pagination limits

    @Test
    func `listTests defaults to a page of at most 50 sessions`() async throws {
        let client = client()
        for index in 0 ..< 45 {
            _ = try await client.sendInvitation(
                campaignID: 101,
                ScreenInvitation(candidateEmail: "page-\(index)@example.com")
            )
        }

        let page = try await client.listTests()
        let pagination = try #require(page.pagination)
        #expect(page.tests.count == ScreenClient.maximumPageSize)
        #expect(pagination.limit == ScreenClient.maximumPageSize)
        #expect(pagination.hasMoreItems == true)
    }

    @Test(arguments: ["0", "51", "-1"])
    func `raw listTests rejects invalid limits`(_ limit: String) async throws {
        let client = client()
        var components = URLComponents(
            url: client.baseURL.appending(path: "/assessment/api/v1.1/tests"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: limit)]
        var request = URLRequest(url: try #require(components.url))
        request.httpMethod = "GET"
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")

        let (data, response) = try await client.session.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("InvalidLimit"))
    }
}

private func containsPDFText(_ data: Data, _ needle: String) -> Bool {
    // Core Graphics Helvetica text is embedded as literal PDF strings.
    String(decoding: data, as: UTF8.self).contains(needle)
}
