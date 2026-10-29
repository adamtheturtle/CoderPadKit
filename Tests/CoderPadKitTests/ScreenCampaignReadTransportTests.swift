@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

struct ScreenCampaignReadTransportTests {
    @Test
    func `definition GET uses the selected Screen origin and key`() async throws {
        let key = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CampaignReadURLProtocol.self]
        let client = ScreenClient(apiKey: key, baseURL: ScreenClient.euBaseURL,
                                  session: URLSession(configuration: configuration))
        let campaign = try await client.getCampaign(id: 121)
        #expect(campaign.id == 121)
        #expect(campaign.settings?.aiAssistEnabled == false)
        #expect(campaign.settings?.enabledCodingAgents == "")
        let request = try #require(CampaignReadURLProtocol.requests.withLock { $0.removeValue(forKey: key) })
        #expect(request.url?.absoluteString == "https://www.codingame.eu/assessment/api/v1.1/campaigns/121")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "API-Key") == key)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.httpBody == nil)
    }
}

private final nonisolated class CampaignReadURLProtocol: URLProtocol {
    static let requests = Mutex<[String: URLRequest]>([:])

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "API-Key") ?? ""
        Self.requests.withLock { $0[key] = request }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let body = #"""
        {"id":121,"name":"Backend","questions":[],"future":true,
         "settings":{"ai_assist_enabled":false,"enabled_coding_agents":"","future":true}}
        """#
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
