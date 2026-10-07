@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Screen raw archive uploads")
struct ScreenTemporaryFileTests {
    @Test(arguments: [200, 400, 403, 500])
    func `upload sends exact binary bytes and never retries failures`(status: Int) async throws {
        let archive = Data([0x1f, 0x8b, 0, 0xff, 0x80, 0])
        let key = "\(status)-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TemporaryFileURLProtocol.self]
        let client = ScreenClient(apiKey: key, session: URLSession(configuration: config))
        do {
            let result = try await client.uploadTemporaryFile(archive)
            #expect(status == 200)
            #expect(result.id == "temporary-archive")
        } catch let error as CoderPadError {
            guard case let .http(code, body) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == status)
            #expect(body == #"{"code":"permission_denied","message":"Upload unavailable"}"#)
        }
        let requests = TemporaryFileURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://screen.coderpad.io/assessment/api/v1.1/temporary-file")
        #expect(request.value(forHTTPHeaderField: "API-Key") == key)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/gzip")
        #expect(request.value(forHTTPHeaderField: "Content-Length") == "6")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.httpBody == archive)
    }

    @Test
    func `empty and maximum archive sizes are accepted`() async throws {
        let key = "200-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TemporaryFileURLProtocol.self]
        let client = ScreenClient(apiKey: key, session: URLSession(configuration: config))
        _ = try await client.uploadTemporaryFile(Data())
        let maximum = Data(repeating: 120, count: ScreenClient.maximumTemporaryFileBytes)
        _ = try await client.uploadTemporaryFile(maximum)
        let requests = TemporaryFileURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.count == 2)
        #expect(requests.first?.value(forHTTPHeaderField: "Content-Length") == "0")
        #expect(requests.last?.value(forHTTPHeaderField: "Content-Length") == "52428800")
        #expect(requests.last?.httpBody == maximum)
    }

    @Test
    func `oversize bodies fail before transport`() async throws {
        let key = "200-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TemporaryFileURLProtocol.self]
        let client = ScreenClient(apiKey: key, session: URLSession(configuration: config))
        let oversize = Data(repeating: 120, count: ScreenClient.maximumTemporaryFileBytes + 1)
        await #expect(throws: CoderPadError.self) { try await client.uploadTemporaryFile(oversize) }
        #expect(TemporaryFileURLProtocol.requests.withLock { $0[key] } == nil)
    }

    @Test
    func `demo uploads return unique references and preserve authorization failures`() async throws {
        let client = ScreenClient.mock(key: "temporary-demo-\(UUID().uuidString)")
        let first = try await client.uploadTemporaryFile(Data([0x1f, 0x8b]))
        let second = try await client.uploadTemporaryFile(Data())
        #expect(UUID(uuidString: first.id) != nil)
        #expect(first.id != second.id)
        do {
            _ = try await ScreenClient.mock(unauthorized: true).uploadTemporaryFile(Data())
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case .http(401, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }

    @Test
    func `invalid upload responses use the public decode error`() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TemporaryFileURLProtocol.self]
        let key = "201-\(UUID().uuidString)"
        do {
            _ = try await ScreenClient(apiKey: key, session: URLSession(configuration: config))
                .uploadTemporaryFile(Data())
            Issue.record("Expected a decode error")
        } catch let error as CoderPadError {
            guard case .decode = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
        TemporaryFileURLProtocol.requests.withLock { _ = $0.removeValue(forKey: key) }
    }
}

private final nonisolated class TemporaryFileURLProtocol: URLProtocol {
    static let requests = Mutex<[String: [URLRequest]]>([:])
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "API-Key") ?? ""
        var captured = request
        captured.httpBody = request.httpBody ?? MockRequestBody.drain(stream: request.httpBodyStream)
        Self.requests.withLock { $0[key, default: []].append(captured) }
        let status = Int(key.split(separator: "-").first ?? "") ?? 500
        let body = switch status {
        case 200: #"{"id":"temporary-archive"}"#
        case 201: #"{"id":123}"#
        default: #"{"code":"permission_denied","message":"Upload unavailable"}"#
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
