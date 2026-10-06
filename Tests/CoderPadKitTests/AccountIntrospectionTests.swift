import CoderPadKit
import CoderPadKitMock
import Foundation
import Synchronization
import Testing

@Suite("Account introspection", .serialized)
struct AccountIntrospectionTests {
    @Test
    func `each product uses its own key and endpoint`() async throws {
        AccountCaptureURLProtocol.requests.withLock { $0 = [] }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountCaptureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let interview = CoderPadClient(apiKey: "interview-key", session: session)
        let screen = ScreenClient(apiKey: "screen-key", session: session)
        let user = try await interview.getUser()
        let account = try await screen.getMe()
        #expect(user.name == nil)
        #expect(!user.allowPadCreation)
        #expect(user.analyticsID == "")
        #expect(account.organizationID == "org")
        #expect(account.recruiterID == "recruiter")
        #expect(account.teams.map(\.name) == [""])
        #expect(account.teams.map(\.isDefault) == [true])
        let requests = AccountCaptureURLProtocol.requests.withLock { $0 }
        #expect(requests.map { $0.url?.absoluteString } == [
            "https://app.coderpad.io/api/user",
            "https://screen.coderpad.io/assessment/api/v1.1/me"
        ])
        #expect(requests.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer interview-key", nil])
        #expect(requests.map { $0.value(forHTTPHeaderField: "API-Key") } == [nil, "screen-key"])
    }

    @Test
    func `demo routes supply account data and preserve authorization failures`() async throws {
        let user = try await CoderPadClient.mock().getUser()
        let account = try await ScreenClient.mock().getMe()
        #expect(user.name == "Demo recruiter")
        #expect(user.allowPadCreation)
        #expect(account.teams.map(\.name) == ["Demo team"])
        do {
            _ = try await CoderPadClient.mock(unauthorized: true).getUser()
            Issue.record("Expected Interview authorization failure")
        } catch let error as CoderPadError {
            #expect(error.isUnauthorized)
        }
        do {
            _ = try await ScreenClient.mock(unauthorized: true).getMe()
            Issue.record("Expected Screen authorization failure")
        } catch let error as CoderPadError {
            #expect(error.isUnauthorized)
        }
    }

    @Test
    func `an empty Screen team list remains empty`() throws {
        let account = try JSONDecoder().decode(ScreenAccount.self, from: Data(
            #"{"organization_id":"org","recruiter_id":"recruiter","teams":[]}"#.utf8
        ))
        #expect(account.teams == [])
    }
}

private final nonisolated class AccountCaptureURLProtocol: URLProtocol {
    static let requests = Mutex<[URLRequest]>([])

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        guard let url = request.url else { return }
        let json = url.path == "/api/user"
            ? #"{"status":"OK","name":null,"allow_pad_creation":false,"analytics_id":""}"#
            : #"""
              {"organization_id":"org","recruiter_id":"recruiter",
               "teams":[{"id":"team","name":"","is_default":true}]}
              """#
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
