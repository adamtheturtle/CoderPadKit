@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Campaign creation transport")
struct ScreenCampaignCreationTransportTests {
    @Test(arguments: [201, 400, 403, 409, 500])
    func `creation authenticates and never retries failures`(status: Int) async throws {
        let key = "\(status)-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CampaignCreationURLProtocol.self]
        let client = ScreenClient(apiKey: key, session: URLSession(configuration: config))
        let id = UUID(uuidString: "4143ca74-2f0e-4151-90d6-e1428739450b")!
        let input = ScreenCampaignCreation(name: "Backend", questions: [.question(id)])
        do {
            let result = try await client.createCampaign(input)
            #expect(status == 201)
            #expect(result.id == 123)
        } catch let error as CoderPadError {
            guard case let .http(code, body) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == status)
            #expect(body == #"{"code":"feature_unavailable","message":"Unavailable setting"}"#)
        }
        let requests = CampaignCreationURLProtocol.requests.withLock { $0.removeValue(forKey: key) ?? [] }
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url?.absoluteString == "https://screen.coderpad.io/assessment/api/v1.1/campaigns")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "API-Key") == key)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode(JSONValue.self, from: body)
            == JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(input)))
    }
}

private final nonisolated class CampaignCreationURLProtocol: URLProtocol {
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
        let body = status == 201 ? #"{"id":123}"#
            : #"{"code":"feature_unavailable","message":"Unavailable setting"}"#
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
