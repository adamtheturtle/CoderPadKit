import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Project pads and language discovery", .serialized)
struct ProjectPadTests {
    @Test
    func `project overlays encode as JSON strings with empty and deleted files`() throws {
        let body = PadCreate(language: "multifile_python", fileContents: [
            .init(path: "main.py", contents: "", hidden: true),
            .init(path: "old.py", deleted: true)
        ])
        let data = try JSONEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let files = try #require(object["file_contents"] as? String)
        let decoded = try JSONDecoder().decode([QuestionFileContent].self, from: Data(files.utf8))
        #expect(decoded.map(\.path) == ["main.py", "old.py"])
        #expect(decoded.first?.contents == "")
        #expect(decoded.first?.hidden == true)
        #expect(decoded.last?.contents == nil)
        #expect(decoded.last?.deleted == true)
        let roundTrip = try JSONDecoder().decode(PadCreate.self, from: data)
        #expect(roundTrip.fileContents?.last?.deleted == true)
    }

    @Test
    func `question and single file seeds exclude project overlays`() throws {
        #expect(throws: (any Error).self) {
            try JSONEncoder().encode(PadCreate(contents: "", fileContents: []))
        }
        #expect(throws: (any Error).self) {
            try JSONEncoder().encode(PadCreate(questionID: 42, fileContents: []))
        }
    }

    @Test
    func `catalogue reads preserve complete metadata and use GET`() async throws {
        CatalogueProtocol.requests.withLock { $0 = [] }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CatalogueProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = CoderPadClient(apiKey: "test-key", session: session)
        let expected = JSONValue.object(["future_metadata": .array([.string("starter"), .null])])
        #expect(try await client.listLanguages() == expected)
        #expect(try await client.getLanguage("multifile_python") == expected)
        await #expect(throws: CoderPadError.self) { try await client.getLanguage("../pads") }
        let requests = CatalogueProtocol.requests.withLock { $0 }
        #expect(requests.map { $0.url?.path } == ["/api/languages", "/api/languages/multifile_python"])
        #expect(requests.allSatisfy { $0.httpMethod == "GET" })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-key" })
    }
}

private final nonisolated class CatalogueProtocol: URLProtocol {
    static let requests = Mutex<[URLRequest]>([])
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"future_metadata":["starter",null]}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
