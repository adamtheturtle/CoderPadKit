@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Screen question bank transport")
struct ScreenQuestionBankTransportTests {
    private let id = UUID(uuidString: "4143ca74-2f0e-4151-90d6-e1428739450b")!

    @Test
    func `all pages retain exact encoded filters and Screen authentication`() async throws {
        let key = "pages-\(UUID().uuidString)"
        let filters = ScreenQuestionFilters(type: "CODE", durationSecondsMin: 0, durationSecondsMax: 120,
                                             difficulty: .easy, domain: "a&b+c", skill: "C#",
                                             programmingLanguage: "C++", fromCoderPadQuestionBank: false,
                                             product: .screen, sort: .title, order: .desc)
        let result = try await client(key).listAllQuestions(filters: filters, limit: 1)
        #expect(result.map(\.id) == [id])
        let requests = BankURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        let base = "https://screen.coderpad.io/assessment/api/v1.1/questions"
        let query = "?type=CODE&duration_seconds_min=0&duration_seconds_max=120&difficulty=EASY"
            + "&domain=a%26b%2Bc&skill=C%23&programming_language=C%2B%2B&from_coderpad_question_bank=false"
            + "&product=SCREEN&sort=title&order=desc"
        #expect(requests.map { $0.url?.absoluteString } == [
            base + query + "&start=0&limit=1", base + query + "&start=1&limit=1"
        ])
        #expect(requests.map(\.httpMethod) == ["GET", "GET"])
        #expect(requests.map { $0.value(forHTTPHeaderField: "API-Key") } == [key, key])
        #expect(requests.map { $0.value(forHTTPHeaderField: "Authorization") } == [nil, nil])
    }

    @Test(arguments: ["repeated", "backward", "missing"])
    func `incoherent next offsets fail instead of looping`(mode: String) async throws {
        let key = "\(mode)-\(UUID().uuidString)"
        defer { BankURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) } }
        let error = await #expect(throws: CoderPadError.self) {
            try await client(key).listAllQuestions(start: 2)
        }
        guard case let .decode(message) = error else {
            Issue.record("Expected a pagination error")
            return
        }
        #expect(message == "Screen question pagination did not advance.")
        #expect(BankURLProtocol.requests.withLock { $0[key]?.count } == 1)
    }

    @Test
    func `partial pagination and empty lists decode without inventing metadata`() async throws {
        let key = "partial-\(UUID().uuidString)"
        defer { BankURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) } }
        let page = try await client(key).listQuestions()
        #expect(page.questions == [])
        #expect(page.pagination?.total == 0)
        #expect(page.pagination?.start == nil)
        #expect(page.pagination?.hasMoreItems == nil)
        #expect(try await client(key).listAllQuestions() == [])
    }

    @Test
    func `writes retain exact payload UUID paths and case insensitive Location`() async throws {
        let key = "write-\(UUID().uuidString)"
        let client = client(key)
        let input = ScreenQuestionSave(type: .text, durationSeconds: 0, title: [:], locales: [],
                                       automaticallySelectable: false,
                                       textDetails: ScreenTextInput(evaluationMode: .manual))
        let created = try await client.createQuestion(input)
        #expect(created.location == "/created-question")
        #expect(created.question.id == id)
        let updated = try await client.updateQuestion(id: id, input)
        #expect(updated.id == id)
        let requests = BankURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.map(\.httpMethod) == ["POST", "PUT"])
        #expect(requests.map { $0.url?.path } == [
            "/assessment/api/v1.1/questions", "/assessment/api/v1.1/questions/\(id.uuidString.lowercased())"
        ])
        for request in requests {
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "API-Key") == key)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = try #require(request.httpBody)
            let expected = Data(#"""
            {"type":"TEXT","duration_seconds":0,"title":{},"locales":[],"automatically_selectable":false,
            "text_details":{"evaluation_mode":"MANUAL"}}
            """#.utf8)
            #expect(try JSONDecoder().decode(JSONValue.self, from: body)
                == JSONDecoder().decode(JSONValue.self, from: expected))
        }
    }

    @Test(arguments: [400, 403, 409, 500])
    func `business rule failures are never retried`(status: Int) async throws {
        let key = "\(status)-\(UUID().uuidString)"
        let error = await #expect(throws: CoderPadError.self) {
            try await client(key).createQuestion(ScreenQuestionSave(type: .text))
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected an HTTP error")
            return
        }
        #expect(code == status)
        #expect(body == #"{"message":"Business rule rejected the write"}"#)
        let requests = BankURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.count == 1)
    }

    private func client(_ key: String) -> ScreenClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BankURLProtocol.self]
        return ScreenClient(apiKey: key, session: URLSession(configuration: config))
    }
}

private final nonisolated class BankURLProtocol: URLProtocol {
    static let requests = Mutex<[String: [URLRequest]]>([:])
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "API-Key") ?? ""
        var captured = request
        if let stream = request.httpBodyStream, captured.httpBody == nil {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        Self.requests.withLock { $0[key, default: []].append(captured) }
        let mode = String(key.split(separator: "-").first ?? "")
        let status = Int(mode) ?? (request.httpMethod == "POST" ? 201 : 200)
        let body = responseBody(mode: mode, status: status)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json",
                                                            "location": "/created-question"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    private func responseBody(mode: String, status: Int) -> String {
        if status >= 400 { return #"{"message":"Business rule rejected the write"}"# }
        let question = #"{"id":"4143ca74-2f0e-4151-90d6-e1428739450b","version":1,"type":"TEXT"}"#
        switch mode {
        case "write": return question
        case "partial": return #"{"questions":[],"pagination":{"total":0}}"#
        case "repeated": return #"{"questions":[],"pagination":{"has_more_items":true,"next_start":2}}"#
        case "backward": return #"{"questions":[],"pagination":{"has_more_items":true,"next_start":1}}"#
        case "missing": return #"{"questions":[],"pagination":{"has_more_items":true}}"#
        default:
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let last = items.contains { $0.name == "start" && $0.value == "1" }
            return last ? #"{"questions":[],"pagination":{"has_more_items":false}}"#
                : "{\"questions\":[\(question)],\"pagination\":{\"has_more_items\":true,\"next_start\":1}}"
        }
    }
}
