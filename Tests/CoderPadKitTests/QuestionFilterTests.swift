import CoderPadKit
import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Question filters", .serialized)
struct QuestionFilterTests {
    @Test
    func `personal filters and title sort survive parallel pages and streams`() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let questions = try await client.listQuestions(
            sort: "title,asc", text: "C++ & arrays", padTypes: [.live, .takeHome]
        )
        #expect(questions.map(\.id) == Array(1...51))
        checkRequests(path: "/api/questions/", filters: [
            URLQueryItem(name: "text", value: "C++ & arrays"),
            URLQueryItem(name: "pad_types[]", value: "live"),
            URLQueryItem(name: "pad_types[]", value: "take_home"),
            URLQueryItem(name: "sort", value: "title,asc")
        ])
        QuestionFilterCaptureURLProtocol.requests.withLock { $0 = [] }
        var last: [Question] = []
        for try await page in client.listQuestionsIncrementally(
            sort: "used,desc", text: "C++ & arrays", padTypes: [.live, .takeHome]
        ) { last = page }
        #expect(last.count == 51)
        checkRequests(path: "/api/questions/", filters: [
            URLQueryItem(name: "text", value: "C++ & arrays"),
            URLQueryItem(name: "pad_types[]", value: "live"),
            URLQueryItem(name: "pad_types[]", value: "take_home"),
            URLQueryItem(name: "sort", value: "used,desc")
        ])
    }

    @Test
    func `organization filters survive both pagination interfaces`() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let questions = try await client.listOrganizationQuestions(
            sort: "used,asc", padType: .takeHome, language: "python3"
        )
        #expect(questions.count == 51)
        let filters = [
            URLQueryItem(name: "pad_type", value: "take_home"),
            URLQueryItem(name: "language", value: "python3"),
            URLQueryItem(name: "sort", value: "used,asc")
        ]
        checkRequests(path: "/api/organization/questions", filters: filters)
        QuestionFilterCaptureURLProtocol.requests.withLock { $0 = [] }
        var last: [Question] = []
        for try await page in client.listOrganizationQuestionsIncrementally(
            sort: "used,asc", padType: .takeHome, language: "python3"
        ) { last = page }
        #expect(last.count == 51)
        checkRequests(path: "/api/organization/questions", filters: filters)
    }

    @Test
    func `mock filters repeated types and includes any-format questions`() async throws {
        let client = CoderPadClient.mock()
        let matches = try await client.listQuestions(sort: "title,asc", text: "FizzBuzz", padTypes: [.live, .takeHome])
        #expect(matches.map(\.id) == [101])
        let any = try await client.createQuestion(
            QuestionCreate(title: "Any format", language: "python3", padType: "any")
        )
        let live = try await client.listOrganizationQuestions(sort: "title,asc", padType: .live, language: "python3")
        #expect(live.map(\.id) == [any.id, 101, 104])
        let takeHome = try await client.listOrganizationQuestions(padType: .takeHome, language: "python3")
        #expect(takeHome.map(\.id) == [any.id])
        let ranked = try await client.listQuestions(sort: "used,asc")
        #expect(ranked.compactMap(\.used) == ranked.compactMap(\.used).sorted())
    }

    @Test
    func `question sort validation stays separate from pad validation`() throws {
        #expect(try InterviewQuestionSort.validated(nil) == nil)
        for sort in InterviewQuestionSort.allCases {
            #expect(try InterviewQuestionSort.validated(sort.rawValue) == sort.rawValue)
        }
        #expect(try InterviewQuestionSort.validated(" TITLE , DESC ") == "title,desc")
        #expect(throws: CoderPadError.self) { try InterviewListSort.validated("title,asc") }
        #expect(throws: CoderPadError.self) { try InterviewQuestionSort.validated("used,up") }
    }

    @Test
    func `invalid stream sorts fail before a request starts`() async {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        do {
            for try await _ in client.listQuestionsIncrementally(sort: "used,up") {}
            Issue.record("Expected invalid sort")
        } catch {
            #expect(error is CoderPadError)
        }
        #expect(QuestionFilterCaptureURLProtocol.requests.withLock { $0.isEmpty })
    }

    private func makeClient() -> (CoderPadClient, URLSession) {
        QuestionFilterCaptureURLProtocol.requests.withLock { $0 = [] }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QuestionFilterCaptureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return (CoderPadClient(apiKey: "filter-key", session: session), session)
    }

    private func checkRequests(path: String, filters: [URLQueryItem]) {
        let requests = QuestionFilterCaptureURLProtocol.requests.withLock { $0 }
        #expect(requests.count == 2)
        for request in requests {
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            #expect(components?.path == path)
            let items = components?.queryItems?.filter { $0.name != "page" } ?? []
            #expect(items.sorted(by: queryOrder) == filters.sorted(by: queryOrder))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer filter-key")
        }
    }

    private func queryOrder(_ lhs: URLQueryItem, _ rhs: URLQueryItem) -> Bool {
        (lhs.name, lhs.value ?? "") < (rhs.name, rhs.value ?? "")
    }
}

private final nonisolated class QuestionFilterCaptureURLProtocol: URLProtocol {
    static let requests = Mutex<[URLRequest]>([])

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let second = query.contains { $0.name == "page" && $0.value == "2" }
        let ids = second ? Array(51...51) : Array(1...50)
        let payload: [String: Any] = [
            "status": "OK", "questions": ids.map { ["id": $0, "title": "Question \($0)"] },
            "total": 51, "next_page": second ? NSNull() : "https://app.coderpad.io\(url.path)?page=2"
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
