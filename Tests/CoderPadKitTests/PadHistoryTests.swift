//
//  PadHistoryTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Pad history models")
struct PadHistoryModelTests {
    @Test
    func `history decodes in timestamp and id order then replays`() throws {
        // A single-line JSON fixture: kept verbatim so it reads as the wire format does.
        // swiftlint:disable:next line_length
        let json = #"{"later":{"a":"author-2","o":[2,"!"],"t":2},"same-time-b":{"a":"author-3","o":[3],"t":3},"earlier":{"a":"author-1","o":[1,"i"],"t":1},"same-time-a":{"a":"author-3","o":[3],"t":3}}"#
        let data = Data(json.utf8)

        let history = try CoderPadClient.decoder.decode(PadHistory.self, from: data)

        #expect(history.map(\.id) == ["earlier", "later", "same-time-a", "same-time-b"])
        #expect(history.replay(initialContents: "h") == "hi!")
    }

    @Test
    func `entry applies retains inserts and deletes`() {
        let entry = PadHistoryEntry(
            id: "entry-1",
            author: "author-1",
            operations: [.retain(1), .insert("X"), .delete(2)],
            timestamp: 1_700_000_000_000
        )

        #expect(entry.applying(to: "abcd") == "aXd")
    }

    @Test
    func `operation counts use JavaScript UTF-16 offsets`() {
        let entry = PadHistoryEntry(
            id: "entry-1",
            author: "author-1",
            operations: [.retain(2), .insert("!"), .retain(1)],
            timestamp: 1
        )

        // The emoji occupies two UTF-16 code units, so retaining two places the
        // insertion after it rather than after the following letter.
        #expect(entry.applying(to: "🙂a") == "🙂!a")
    }
}

@Suite("Pad history client")
struct PadHistoryClientTests {
    private func client() -> CoderPadClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PadHistoryURLProtocol.self]
        return CoderPadClient(
            apiKey: "secret-that-must-not-leave-coderpad",
            session: URLSession(configuration: configuration)
        )
    }

    @Test
    func `fetches history without sending the CoderPad API key`() async throws {
        let history = try await client().padHistory(
            historyURL: "https://coderpad-1.firebaseio.com/history.json"
        )

        #expect(history.map(\.id) == ["earlier", "later"])
        #expect(history.replay(initialContents: "h") == "hi!")
    }

    @Test
    func `Firebase null response is an empty history`() async throws {
        let history = try await client().padHistory(
            historyURL: "https://coderpad-1.firebaseio.com/empty.json"
        )

        #expect(history.isEmpty)
        #expect(history.replay() == "")
    }

    @Test
    func `Firebase HTTP errors use CoderPadError`() async throws {
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client().padHistory(
                historyURL: "https://coderpad-1.firebaseio.com/missing.json"
            )
        }

        guard case let .http(status, _) = error else {
            Issue.record("Expected a .http error, got \(String(describing: error))")
            return
        }
        #expect(status == 404)
    }

    @Test
    func `mock environment history replays to its current file contents`() async throws {
        let client = CoderPadClient.mock(key: "history-\(UUID().uuidString)")
        let environment = try await client.padEnvironment(id: 1)
        let file = try #require(environment.fileContents.first)
        let historyURL = try #require(file.history)

        let history = try await client.padHistory(historyURL: historyURL)

        #expect(history.replay() == file.contents)
    }

    @Test
    func `mock history resembles anonymous multi-editor playback`() async throws {
        let client = CoderPadClient.mock(key: "history-shape-\(UUID().uuidString)")
        let pad = try await client.getPad(id: "DEMOABC1")
        let environment = try await client.padEnvironment(id: #require(pad.activeEnvironmentID))
        let file = try #require(environment.fileContents.first)
        let history = try await client.padHistory(historyURL: #require(file.history))

        #expect(history.count > 400)
        #expect(Set(history.map(\.author)) == [
            "CoderPad", "4503601411610331", "9988776655443322"
        ])
        #expect(history.suffix(2).first?.timestamp == history.last?.timestamp)
        #expect(history.contains { $0.operations.contains(.insert("x")) })
        #expect(history.contains { $0.operations.contains(.delete(1)) })
        #expect(history.contains { $0.operations.contains(.insert("# Consider the empty-input case\n")) })
        #expect(history.replay() == file.contents)
        #expect(history.dropFirst().allSatisfy { !pad.participants.contains($0.author) })

        let gaps = zip(history, history.dropFirst()).map { $1.timestamp - $0.timestamp }
        #expect(gaps.contains(0))
        #expect(gaps.contains { $0 > 60_000 })

        let runDates = try await client.padEvents(padID: pad.id)
            .filter { $0.kind == "ran" }
            .compactMap(\.createdAt)
            .map { Int64($0.timeIntervalSince1970 * 1000) }
        let firstTimestamp = try #require(history.first?.timestamp)
        let lastTimestamp = try #require(history.last?.timestamp)
        #expect(runDates.allSatisfy { firstTimestamp ... lastTimestamp ~= $0 })
    }

    @Test
    func `mock can advertise one unavailable text-file history`() async throws {
        let client = CoderPadClient.mock(key: "partial-history-\(UUID().uuidString)")
        let environment = try await client.padEnvironment(id: 34)
        let file = try #require(environment.fileContents.dropFirst().first)

        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.padHistory(historyURL: #require(file.history))
        }
        guard case let .http(status, _) = error else {
            Issue.record("Expected a .http error, got \(String(describing: error))")
            return
        }
        #expect(status == 404)
    }
}

/// A Firebase stand-in that rejects accidental API-key leakage and serves success,
/// empty, and error responses according to the requested path.
private final nonisolated class PadHistoryURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let hasExpectedRequestShape = request.httpMethod == "GET"
            && request.value(forHTTPHeaderField: "Accept") == "application/json"
            && request.value(forHTTPHeaderField: "Authorization") == nil

        let status: Int
        let body: Data
        if !hasExpectedRequestShape {
            status = 400
            body = Data(#"{"error":"unexpected request headers"}"#.utf8)
        } else {
            switch url.path {
            case "/history.json":
                status = 200
                body = Data(
                    #"{"later":{"a":"author-1","o":[2,"!"],"t":2},"earlier":{"a":"author-1","o":[1,"i"],"t":1}}"#.utf8
                )
            case "/empty.json":
                status = 200
                body = Data("null".utf8)
            default:
                status = 404
                body = Data("Not Found".utf8)
            }
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
