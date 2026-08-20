//
//  MockScreenFidelityTests.swift
//  CoderPadKitTests
//
//  Regression coverage for Screen mock fidelity and registry bounds (#129–#138).
//

@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock Screen fidelity")
struct MockScreenFidelityTests {
    private func client(_ label: String = "fidelity") -> ScreenClient {
        ScreenClient.mock(key: "\(label)-\(UUID().uuidString)")
    }

    private func raw(
        _ client: ScreenClient,
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(
            url: client.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: try #require(components.url))
        request.httpMethod = method
        request.httpBody = body
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await client.session.data(for: request)
        return (data, try #require(response as? HTTPURLResponse))
    }

    // MARK: - #129

    @Test
    func `sendInvitation rejects nonexistent campaigns`() async throws {
        let screen = client("invite-missing")
        let beforeCount = try await screen.listTests(limit: 50).pagination?.total
        do {
            _ = try await screen.sendInvitation(
                campaignID: 999_999,
                ScreenInvitation(candidateEmail: "missing-campaign-\(UUID().uuidString)@example.com")
            )
            Issue.record("Expected InvalidCampaignId")
        } catch let error as CoderPadError {
            #expect(error.description.contains("InvalidCampaignId"))
        }
        // A rejected invite must not grow the store (#129).
        let afterCount = try await screen.listTests(limit: 50).pagination?.total
        #expect(beforeCount == afterCount)
    }

    @Test
    func `sendInvitation rejects archived campaigns`() async throws {
        let screen = client("invite-archived")
        do {
            _ = try await screen.sendInvitation(
                campaignID: 105,
                ScreenInvitation(candidateEmail: "legacy@example.com")
            )
            Issue.record("Expected archived campaign to fail")
        } catch let error as CoderPadError {
            #expect(error.description.contains("InvalidCampaignId"))
        }
    }

    // MARK: - #130 / #135

    @Test
    func `cancel resend and delete reject unknown test IDs`() async throws {
        let screen = client("unknown-actions")
        do {
            try await screen.cancelTest(id: 999_999)
            Issue.record("Expected NotFoundTestId for cancel")
        } catch let error as CoderPadError {
            #expect(error.description.contains("NotFoundTestId"))
        }
        do {
            try await screen.resendTest(id: 999_999)
            Issue.record("Expected NotFoundTestId for resend")
        } catch let error as CoderPadError {
            #expect(error.description.contains("NotFoundTestId"))
        }
        do {
            try await screen.deleteTest(id: 999_999)
            Issue.record("Expected NotFoundTestId for delete")
        } catch let error as CoderPadError {
            #expect(error.description.contains("NotFoundTestId"))
        }
    }

    @Test
    func `cancel and resend reject completed sessions without mutating them`() async throws {
        let screen = client("lifecycle")
        let before = try await screen.getTest(id: 5001)
        #expect(before.status == "completed")

        do {
            try await screen.cancelTest(id: 5001)
            Issue.record("Expected InvalidTestId for cancel")
        } catch let error as CoderPadError {
            #expect(error.description.contains("InvalidTestId"))
        }
        do {
            try await screen.resendTest(id: 5001)
            Issue.record("Expected InvalidTestId for resend")
        } catch let error as CoderPadError {
            #expect(error.description.contains("InvalidTestId"))
        }

        let after = try await screen.getTest(id: 5001)
        #expect(after.status == "completed")
    }

    @Test
    func `cancel and resend succeed for waiting invitations`() async throws {
        let screen = client("waiting-actions")
        try await screen.resendTest(id: 5004)
        try await screen.cancelTest(id: 5004)
        let cancelled = try await screen.getTest(id: 5004)
        #expect(cancelled.status == "cancelled")
    }

    // MARK: - #131 / #136

    @Test
    func `report export rejects unfinished sessions`() async throws {
        let screen = client("report-waiting")
        do {
            _ = try await screen.testReport(id: 5004)
            Issue.record("Expected unfinished report to fail")
        } catch let error as CoderPadError {
            #expect(error.description.contains("InvalidTestId"))
        }
    }

    @Test
    func `anonymous report export omits the candidate name`() async throws {
        let screen = client("report-anon")
        let named = try await screen.testReport(id: 5001, anonymous: false)
        let anonymous = try await screen.testReport(id: 5001, anonymous: true)
        let namedText = String(decoding: named, as: UTF8.self)
        let anonymousText = String(decoding: anonymous, as: UTF8.self)
        #expect(namedText.contains("Ada Lovelace"))
        #expect(!anonymousText.contains("Ada Lovelace"))
        #expect(anonymousText.contains("Anonymous"))
        #expect(named != anonymous)
    }

    @Test
    func `report options change the generated PDF`() async throws {
        let screen = client("report-opts")
        let full = try await screen.testReport(
            id: 5001,
            reportType: .full,
            includeRank: true,
            includeComparativeScore: true
        )
        let simplified = try await screen.testReport(
            id: 5001,
            reportType: .simplified,
            includeRank: false,
            includeComparativeScore: false
        )
        let fullText = String(decoding: full, as: UTF8.self)
        let simplifiedText = String(decoding: simplified, as: UTF8.self)
        #expect(fullText.contains("Demo Report"))
        #expect(fullText.contains("comparative="))
        #expect(fullText.contains("rank="))
        #expect(simplifiedText.contains("Simplified Report"))
        #expect(!simplifiedText.contains("comparative="))
        #expect(!simplifiedText.contains("rank="))
        #expect(full != simplified)
    }

    // MARK: - #132

    @Test
    func `listTests filters by product`() async throws {
        let screen = client("product")
        let screenPage = try await screen.listTests(product: "screen", limit: 50)
        let mapPage = try await screen.listTests(product: "map", limit: 50)
        #expect(!screenPage.tests.isEmpty)
        #expect(!mapPage.tests.isEmpty)
        #expect(Set(screenPage.tests.map(\.id)).isDisjoint(with: Set(mapPage.tests.map(\.id))))
        #expect(mapPage.tests.contains { $0.id == 5401 })
        #expect(!screenPage.tests.contains { $0.id == 5401 })
    }

    // MARK: - #133

    @Test
    func `listTests from and to filter by send time not activity`() async throws {
        let screen = client("send-range")
        // Session 5001: sent 9 days ago, last activity ~8 days ago. A window between
        // those instants must exclude it when filtering by send_time.
        let session = try await screen.getTest(id: 5001)
        let send = try #require(session.sendTime)
        let activity = try #require(session.lastActivityTime)
        #expect(activity > send)

        let between = try await screen.listTests(from: send + 1, until: activity, limit: 50)
        #expect(!between.tests.contains { $0.id == 5001 })

        let coveringSend = try await screen.listTests(from: send - 1, until: send + 1, limit: 50)
        #expect(coveringSend.tests.contains { $0.id == 5001 })
    }

    // MARK: - #134

    @Test
    func `listTests defaults limit to 50 and rejects out of range values`() async throws {
        let screen = client("limits")
        for index in 0 ..< 55 {
            _ = try await screen.sendInvitation(
                campaignID: 101,
                ScreenInvitation(candidateEmail: "bulk\(index)@example.com")
            )
        }

        let defaulted = try await screen.listTests()
        #expect(defaulted.tests.count == ScreenClient.maximumPageSize)
        #expect(defaulted.pagination?.limit == ScreenClient.maximumPageSize)
        #expect(defaulted.pagination?.hasMoreItems == true)

        let (zeroData, zeroHTTP) = try await raw(
            screen, method: "GET", path: "/assessment/api/v1.1/tests",
            query: [URLQueryItem(name: "limit", value: "0")]
        )
        #expect(zeroHTTP.statusCode == 400)
        #expect(String(decoding: zeroData, as: UTF8.self).contains("InvalidParameter"))

        let (overData, overHTTP) = try await raw(
            screen, method: "GET", path: "/assessment/api/v1.1/tests",
            query: [URLQueryItem(name: "limit", value: "51")]
        )
        #expect(overHTTP.statusCode == 400)
        #expect(String(decoding: overData, as: UTF8.self).contains("InvalidParameter"))
    }

    // MARK: - #137

    @Test
    func `routes without the versioned API prefix return 404`() async throws {
        let screen = client("prefix")
        let (data, http) = try await raw(screen, method: "GET", path: "/tests")
        #expect(http.statusCode == 404)
        #expect(String(decoding: data, as: UTF8.self).contains("not_found"))
    }

    // MARK: - #138

    @Test
    func `mock state registries reset and bound retention`() async throws {
        let keptKey = "screen-kept-\(UUID().uuidString)"
        let screen = ScreenClient.mock(key: keptKey)
        try await screen.setWebhookURL("https://coderpad.io/kept")
        #expect(try await screen.webhookURL() == "https://coderpad.io/kept")

        ScreenClient.resetMockState(forKey: keptKey)
        #expect(try await ScreenClient.mock(key: keptKey).webhookURL() == nil)

        let interviewKey = "interview-kept-\(UUID().uuidString)"
        let interview = CoderPadClient.mock(key: interviewKey)
        _ = try await interview.createPad(PadCreate(title: "retain"))
        MockServer.resetState(forKey: interviewKey)
        let afterReset = try await CoderPadClient.mock(key: interviewKey).listPads()
        #expect(!afterReset.contains { $0.title == "retain" })

        let prefix = "evict-\(UUID().uuidString)-"
        for index in 0 ... MockScreenStateRegistry.maximumRetainedKeys {
            _ = try await ScreenClient.mock(key: "\(prefix)\(index)").listCampaigns()
        }
        #expect(MockScreenStateRegistry.retainedKeyCount <= MockScreenStateRegistry.maximumRetainedKeys)

        let interviewPrefix = "ievict-\(UUID().uuidString)-"
        for index in 0 ... MockStateRegistry.maximumRetainedKeys {
            _ = try await CoderPadClient.mock(key: "\(interviewPrefix)\(index)").listPads()
        }
        #expect(MockStateRegistry.retainedKeyCount <= MockStateRegistry.maximumRetainedKeys)
    }
}
