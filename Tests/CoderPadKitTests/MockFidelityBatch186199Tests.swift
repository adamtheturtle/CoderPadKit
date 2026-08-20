//
//  MockFidelityBatch186199Tests.swift
//  CoderPadKitTests
//
//  Regression coverage for mock-fidelity issues #186–#198 (API-only #191/#199 ship
//  separately).
//

@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Mock fidelity #186-#198")
struct MockFidelityBatch186199Tests {
    // MARK: - #186 host-specific routing

    @Test
    func `Firebase-shaped paths on the REST host are not served as history`() async throws {
        var request = URLRequest(
            url: URL(string: "https://app.coderpad.io/DEMOABC1/history.json")!
        )
        request.httpMethod = "GET"
        request.setValue("Bearer route-\(UUID().uuidString)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 404)
        #expect(String(decoding: data, as: UTF8.self).contains("not handled by mock"))
    }

    @Test
    func `REST paths on the Firebase host are not served as API data`() async throws {
        var request = URLRequest(
            url: URL(string: "https://coderpad-1.firebaseio.com/api/quota")!
        )
        request.httpMethod = "GET"

        let (data, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 404)
        #expect(String(decoding: data, as: UTF8.self).contains("history host"))
    }

    // MARK: - #187 / #198 origin interception

    @Test(arguments: [
        "http://app.coderpad.io/api/quota",
        "https://app.coderpad.io:8443/api/quota",
        "http://coderpad-1.firebaseio.com/x/history.json"
    ])
    func `Interview mock ignores insecure schemes and unexpected ports`(_ url: String) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        #expect(!MockServer.handles(request))
    }

    @Test
    func `Interview mock accepts the canonical HTTPS origins`() {
        for url in [
            "https://app.coderpad.io/api/quota",
            "https://app.coderpad.io:443/api/quota",
            "https://coderpad-1.firebaseio.com/x/history.json"
        ] {
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "GET"
            #expect(MockServer.handles(request))
        }
    }

    @Test(arguments: [
        "http://screen.mock.coderpad.io/assessment/api/v1.1/campaigns",
        "https://screen.mock.coderpad.io:8443/assessment/api/v1.1/campaigns"
    ])
    func `Screen mock ignores insecure schemes and unexpected ports`(_ url: String) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        #expect(!MockScreen.handles(request))
        #expect(!MockScreenURLProtocol.canInit(with: request))
        #expect(!MockScreenUnauthorizedURLProtocol.canInit(with: request))
    }

    @Test
    func `Screen mock accepts the exact HTTPS demo origin`() {
        var request = URLRequest(
            url: URL(string: "https://screen.mock.coderpad.io/assessment/api/v1.1/campaigns")!
        )
        request.httpMethod = "GET"
        #expect(MockScreen.handles(request))
    }

    // MARK: - #188 streamed body drain

    @Test
    func `drain consumes a stream that reports no bytes before EOF`() {
        // A custom stream that flips hasBytesAvailable off between chunks, which is
        // exactly the truncation case the old `while hasBytesAvailable` loop missed.
        let stream = ChunkedInputStream(chunks: [Data("{\"a\":".utf8), Data("1}".utf8)])
        let drained = MockRequestBody.drain(stream: stream)
        #expect(drained == Data(#"{"a":1}"#.utf8))
    }

    // MARK: - #189 unknown pad overlay

    @Test
    func `a failed update to an unknown pad leaves no overlay behind`() async throws {
        let client = CoderPadClient.mock(key: "unknown-pad-\(UUID().uuidString)")
        let missingID = "MISSINGPAD"

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.updatePad(PadUpdate(id: missingID, title: "Injected"))
        }
        guard case .http(404, _) = error else {
            Issue.record("Expected HTTP 404, got \(String(describing: error))")
            return
        }

        let pads = try await client.listPads()
        #expect(!pads.contains { $0.id == missingID })
        #expect(!pads.contains { $0.title == "Injected" })
    }

    // MARK: - #190 per-pad environments

    @Test
    func `created pads allocate distinct environments tied to their contents`() async throws {
        let client = CoderPadClient.mock(key: "pad-env-\(UUID().uuidString)")
        let first = try await client.createPad(PadCreate(title: "One", contents: "print(1)"))
        let second = try await client.createPad(PadCreate(title: "Two", contents: "print(2)"))

        let firstEnvID = try #require(first.activeEnvironmentID)
        let secondEnvID = try #require(second.activeEnvironmentID)
        #expect(firstEnvID != secondEnvID)
        #expect(first.padEnvironmentIDs == [firstEnvID])
        #expect(second.padEnvironmentIDs == [secondEnvID])

        let firstEnv = try await client.padEnvironment(id: firstEnvID)
        let secondEnv = try await client.padEnvironment(id: secondEnvID)
        #expect(firstEnv.fileContents.first?.contents == "print(1)")
        #expect(secondEnv.fileContents.first?.contents == "print(2)")
        #expect(firstEnv.padID != secondEnv.padID)
        #expect(firstEnv.padID != 88_112_233)
    }

    // MARK: - #192 updated_at advances

    @Test
    func `pad and question updates advance updated_at`() async throws {
        let client = CoderPadClient.mock(key: "updated-at-\(UUID().uuidString)")
        let beforePad = try await client.getPad(id: "DEMOABC1")
        let beforePadUpdated = try #require(beforePad.updatedAt)
        try await Task.sleep(for: .milliseconds(20))
        let afterPad = try await client.updatePad(PadUpdate(id: "DEMOABC1", title: "Fresh title"))
        #expect(try #require(afterPad.updatedAt) > beforePadUpdated)

        let beforeQuestion = try await client.getQuestion(id: 101)
        let beforeQuestionUpdated = try #require(beforeQuestion.updatedAt)
        try await Task.sleep(for: .milliseconds(20))
        let afterQuestion = try await client.updateQuestion(QuestionUpdate(id: 101, title: "Fresh Q"))
        #expect(try #require(afterQuestion.updatedAt) > beforeQuestionUpdated)
    }

    // MARK: - #193 / #195 org stats window

    @Test
    func `organization stats default window is the last seven days from now`() async throws {
        let frozen = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15-ish
        let previous = MockFixtures.now
        MockFixtures.now = { frozen }
        defer { MockFixtures.now = previous }

        let client = CoderPadClient.mock(key: "stats-window-\(UUID().uuidString)")
        let stats = try await client.organizationStats()
        let start = try #require(stats.startTime)
        let end = try #require(stats.endTime)
        #expect(abs(end.timeIntervalSince(frozen)) < 1)
        #expect(abs(end.timeIntervalSince(start) - 7 * 86_400) < 1)
    }

    @Test
    func `per-user organization stats scale with the requested window`() async throws {
        let client = CoderPadClient.mock(key: "stats-users-\(UUID().uuidString)")
        let shortStart = Date(timeIntervalSince1970: 1_700_000_000)
        let shortEnd = shortStart.addingTimeInterval(2 * 86_400)
        let longEnd = shortStart.addingTimeInterval(30 * 86_400)

        let short = try await client.organizationStats(start: shortStart, end: shortEnd)
        let long = try await client.organizationStats(start: shortStart, end: longEnd)

        #expect(long.padsCreated > short.padsCreated)
        #expect(short.users.map(\.padsCreated).compactMap { $0 }.reduce(0, +) == short.padsCreated)
        #expect(long.users.map(\.padsCreated).compactMap { $0 }.reduce(0, +) == long.padsCreated)
        #expect(long.users.contains { user in
            (user.padsCreated ?? 0) > (short.users.first { $0.email == user.email }?.padsCreated ?? 0)
        })
    }

    // MARK: - #194 quota reset

    @Test
    func `quota reset is in the future relative to the injectable clock`() async throws {
        let frozen = Date(timeIntervalSince1970: 1_800_000_000)
        let previous = MockFixtures.now
        MockFixtures.now = { frozen }
        defer { MockFixtures.now = previous }

        let client = CoderPadClient.mock(key: "quota-reset-\(UUID().uuidString)")
        let quota = try await client.quota()
        let reset = try #require(quota.quotaReset)
        #expect(reset > frozen)
    }

    // MARK: - #196 / #197 invitation validation

    @Test
    func `sendInvitation rejects an oversized candidate name locally`() async {
        let client = ScreenClient.mock(key: "name-too-long-\(UUID().uuidString)")
        let name = String(repeating: "a", count: ScreenClient.maximumCandidateNameLength + 1)
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.sendInvitation(
                campaignID: 101,
                ScreenInvitation(candidateEmail: "a@example.com", candidateName: name)
            )
        }
        guard case let .decode(detail) = error else {
            Issue.record("Expected a local decode error")
            return
        }
        #expect(detail.contains("candidate name"))
    }

    @Test
    func `Screen mock rejects wrong-typed invitation fields without mutating`() async throws {
        let client = ScreenClient.mock(key: "wrong-type-\(UUID().uuidString)")
        let before = try await client.listTests()

        var request = URLRequest(
            url: client.baseURL.appending(path: "/assessment/api/v1.1/campaigns/101/actions/send")
        )
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"candidate_email":123,"candidate_name":{"x":1}}"#.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")

        let (data, response) = try await client.session.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("invalid_request"))

        let after = try await client.listTests()
        #expect(after.tests.count == before.tests.count)
    }

    @Test
    func `Screen mock rejects oversized candidate names with CandidateNameTooLong`() async throws {
        let client = ScreenClient.mock(key: "mock-name-long-\(UUID().uuidString)")
        let name = String(repeating: "n", count: ScreenClient.maximumCandidateNameLength + 1)
        let body = try JSONSerialization.data(withJSONObject: [
            "candidate_email": "pat@example.com",
            "candidate_name": name
        ])

        var request = URLRequest(
            url: client.baseURL.appending(path: "/assessment/api/v1.1/campaigns/101/actions/send")
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.apiKey, forHTTPHeaderField: "API-Key")

        let (data, response) = try await client.session.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("CandidateNameTooLong"))
    }
}

/// InputStream that alternates between reporting bytes and briefly reporting none,
/// forcing readers that only loop on `hasBytesAvailable` to truncate early.
private final nonisolated class ChunkedInputStream: InputStream {
    private var chunks: [Data]
    private var offset = 0
    private var status: Status = .notOpen
    private var pauseBeforeNextChunk = false

    nonisolated init(chunks: [Data]) {
        self.chunks = chunks
        super.init(data: Data())
    }

    override nonisolated var streamStatus: Status { status }

    override nonisolated var hasBytesAvailable: Bool {
        guard status == .open else { return false }
        if pauseBeforeNextChunk {
            pauseBeforeNextChunk = false
            return false
        }
        return !chunks.isEmpty
    }

    override nonisolated func open() {
        status = .open
    }

    override nonisolated func close() {
        status = .closed
    }

    override nonisolated func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard status == .open else { return 0 }
        if chunks.isEmpty {
            status = .atEnd
            return 0
        }
        let chunk = chunks[0]
        let count = min(len, chunk.count - offset)
        chunk.copyBytes(to: buffer, from: offset ..< (offset + count))
        offset += count
        if offset >= chunk.count {
            chunks.removeFirst()
            offset = 0
            // Next hasBytesAvailable poll pretends the producer hasn't delivered yet.
            if !chunks.isEmpty { pauseBeforeNextChunk = true }
            if chunks.isEmpty { status = .atEnd }
        }
        return count
    }

    override nonisolated var delegate: StreamDelegate? {
        get { nil }
        set {}
    }

    override nonisolated func schedule(in _: RunLoop, forMode _: RunLoop.Mode) {}
    override nonisolated func remove(from _: RunLoop, forMode _: RunLoop.Mode) {}
}
