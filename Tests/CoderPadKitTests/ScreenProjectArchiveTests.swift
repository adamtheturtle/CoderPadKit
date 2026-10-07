@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Screen binary project archives")
struct ScreenProjectArchiveTests {
    private let questionID = UUID(uuidString: MockScreenFixtures.archiveQuestionID)!

    @Test
    func `demo returns the candidate archive without interpreting bytes`() async throws {
        let archive = try await ScreenClient.mock().projectArchive(testID: 5001, questionID: questionID)
        #expect(archive == MockScreenFixtures.projectArchive)
        #expect(Array(archive.prefix(2)) == [0x1f, 0x8b])
    }

    @Test(arguments: [400, 404])
    func `JSON errors remain HTTP errors`(status: Int) async throws {
        let error = await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock().projectArchive(testID: status == 400 ? 5003 : 5001,
                                                         questionID: status == 404 ? UUID() : questionID)
        }
        guard case let .http(code, body) = error else {
            Issue.record("Expected HTTP error, got \(String(describing: error))")
            return
        }
        #expect(code == status)
        #expect(body.contains("message"))
    }

    @Test
    func `archive request uses the Screen key binary Accept and UUID path`() async throws {
        let key = "success-\(UUID().uuidString)"
        let client = client(key: key)
        let result = try await client.projectArchive(testID: 1, questionID: questionID)
        #expect(result == Data([0x1f, 0x8b, 0xff, 0]))
        let request = try #require(ArchiveURLProtocol.requests.withLock { $0.removeValue(forKey: key)?.first })
        #expect(request.httpMethod == "GET")
        let path = "/assessment/api/v1.1/tests/1/questions/\(questionID.uuidString.lowercased())/project"
        #expect(request.url?.path == path)
        #expect(request.value(forHTTPHeaderField: "API-Key") == key)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/gzip")
    }

    @Test(arguments: ["declared", "chunked"])
    func `configured response ceilings apply to binary archives`(kind: String) async throws {
        let key = "\(kind)-\(UUID().uuidString)"
        defer { ArchiveURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) } }
        let error = await #expect(throws: CoderPadError.self) {
            try await client(key: key, maximum: 3).projectArchive(testID: 1, questionID: questionID)
        }
        guard case .decode = error else {
            Issue.record("Expected a response limit error")
            return
        }
    }

    @Test
    func `task cancellation stops a pending archive download`() async throws {
        let key = "cancel-\(UUID().uuidString)"
        defer { ArchiveURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) } }
        let client = client(key: key)
        let task = Task { try await client.projectArchive(testID: 1, questionID: questionID) }
        defer { task.cancel() }
        for _ in 0 ..< 100 {
            if ArchiveURLProtocol.requests.withLock({ $0[key] != nil }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(ArchiveURLProtocol.requests.withLock { $0[key]?.count } == 1)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func `transport failures use the public network error`() async throws {
        let key = "network-\(UUID().uuidString)"
        defer { ArchiveURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) } }
        let error = await #expect(throws: CoderPadError.self) {
            try await client(key: key).projectArchive(testID: 1, questionID: questionID)
        }
        guard case let .network(underlying) = error else {
            Issue.record("Expected a network error")
            return
        }
        #expect(underlying.code == .notConnectedToInternet)
    }

    @Test
    func `invalid IDs and unauthorized requests retain existing errors`() async throws {
        await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock().projectArchive(testID: 0, questionID: questionID)
        }
        let error = await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock(unauthorized: true).projectArchive(testID: 5001, questionID: questionID)
        }
        guard case .http(401, _) = error else {
            Issue.record("Expected an unauthorized response")
            return
        }
    }

    private func client(key: String, maximum: Int = ScreenClient.defaultMaximumResponseBodyBytes) -> ScreenClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ArchiveURLProtocol.self]
        config.timeoutIntervalForRequest = 17
        config.timeoutIntervalForResource = 240
        return ScreenClient(apiKey: key, session: URLSession(configuration: config), maximumResponseBodyBytes: maximum)
    }
}

private final nonisolated class ArchiveURLProtocol: URLProtocol {
    static let requests = Mutex<[String: [URLRequest]]>([:])
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "API-Key") ?? ""
        Self.requests.withLock { $0[key, default: []].append(request) }
        if key.hasPrefix("network-") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        var headers = ["Content-Type": "application/gzip"]
        if key.hasPrefix("declared-") { headers["Content-Length"] = "4" }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if key.hasPrefix("cancel-") { return }
        client?.urlProtocol(self, didLoad: Data([0x1f, 0x8b, 0xff, 0]))
        client?.urlProtocolDidFinishLoading(self)
    }
}
