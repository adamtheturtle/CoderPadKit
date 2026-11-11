import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Pad ZIP uploads", .serialized)
struct PadZIPUploadTests {
    @Test
    func `pad ZIP uses pad fields and decodes project responses`() async throws {
        PadZIPCapture.requests.withLock { $0 = [] }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PadZIPCapture.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = CoderPadClient(apiKey: "test-key", session: session)
        let pad = try await client.createPad(
            PadCreate(title: "Project", language: "multifile_python", isPrivate: false),
            zipFile: QuestionZIPUpload(data: Data([0x50, 0x4B, 0x03, 0x04]), filename: "project.zip")
        )
        #expect(pad.language == nil)
        #expect(pad.contents == nil)
        #expect(pad.padEnvironmentIDs == [42])
        let request = try #require(PadZIPCapture.requests.withLock { $0.first })
        #expect(request.method == "POST")
        #expect(request.path.hasPrefix("/api/pads"))
        #expect(request.body.contains("name=\"pad[zip_file]\""))
        #expect(request.body.contains("name=\"pad[language]\""))
        #expect(request.body.contains("multifile_python"))
        #expect(!request.body.contains("question["))
        for body in [PadCreate(contents: ""), PadCreate(fileContents: []), PadCreate(questionID: 42)] {
            await #expect(throws: QuestionMutationValidationError.self) {
                try await client.createPad(body, zipFile: QuestionZIPUpload(data: Data([1]), filename: "project.zip"))
            }
        }
        #expect(PadZIPCapture.requests.withLock { $0.count } == 1)
    }
}

private final nonisolated class PadZIPCapture: URLProtocol {
    struct Capture: Sendable {
        let method: String
        let path: String
        let body: String
    }
    static let requests = Mutex<[Capture]>([])
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        let body = request.httpBody ?? Self.drain(request.httpBodyStream)
        Self.requests.withLock {
            $0.append(Capture(
                method: request.httpMethod ?? "", path: url.path, body: String(decoding: body, as: UTF8.self)
            ))
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let json = #"{"id":"abcdefgh","language":null,"contents":null,"pad_environment_ids":[42]}"#
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    private static func drain(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
