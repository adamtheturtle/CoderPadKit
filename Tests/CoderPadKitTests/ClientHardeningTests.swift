//
//  ClientHardeningTests.swift
//  CoderPadKitTests
//
//  Coverage for Interview/Screen transport hardening (#156–#164 cluster): live
//  session policy, API-key normalization, rawRequest error mapping, and retry
//  classification.
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Interview live session policy")
struct InterviewLiveSessionPolicyTests {
    @Test
    func `live configuration bounds timeouts and disables shared caches`() {
        let configuration = CoderPadClient.makeLiveConfiguration()

        #expect(configuration.timeoutIntervalForRequest == 60)
        #expect(configuration.timeoutIntervalForResource == 120)
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}

@Suite("API key normalization")
struct APIKeyNormalizationTests {
    @Test
    func `Interview trims surrounding whitespace once`() {
        let client = CoderPadClient(
            apiKey: "  interview-key\n",
            session: URLSession(configuration: .ephemeral)
        )
        #expect(client.apiKey == "interview-key")
    }

    @Test(arguments: ["", "   ", "\t\n", "has space", "bad\u{0001}key"])
    func `Interview rejects blank and non-printable keys`(apiKey: String) {
        let client = CoderPadClient(
            apiKey: apiKey,
            session: URLSession(configuration: .ephemeral)
        )
        #expect(client.apiKey.isEmpty)
    }

    @Test
    func `normalized Interview key is used for raw Authorization headers`() async throws {
        AuthorizationCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthorizationCaptureURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "  raw-secret\n",
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: configuration)
        )

        _ = try? await client.rawRequest(path: "/api/quota", responseLimit: 1024)

        #expect(AuthorizationCaptureURLProtocol.capturedAuthorization() == "Bearer raw-secret")
    }
}

@Suite("Retry classification")
struct CoderPadRetryPolicyTests {
    @Test(arguments: [
        URLError.Code.timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .notConnectedToInternet
    ])
    func `mapped and raw transient network errors are retryable`(code: URLError.Code) {
        let urlError = URLError(code)
        #expect(CoderPadRetryPolicy.isTransient(CoderPadError.network(urlError)))
        #expect(CoderPadRetryPolicy.isTransient(urlError))
        #expect(CoderPadRetryPolicy.isTransient(urlError as NSError))
    }

    @Test(arguments: [408, 429, 500, 502, 503, 0])
    func `transient HTTP statuses are retryable`(status: Int) {
        #expect(CoderPadRetryPolicy.isTransient(CoderPadError.http(status, "retry")))
        #expect(CoderPadRetryPolicy.isTransientHTTPStatus(status))
    }

    @Test(arguments: [400, 401, 403, 404])
    func `client HTTP errors are not retryable`(status: Int) {
        #expect(!CoderPadRetryPolicy.isTransient(CoderPadError.http(status, "no")))
    }

    @Test
    func `cancellations and missing keys are not retryable`() {
        #expect(!CoderPadRetryPolicy.isTransient(CancellationError()))
        #expect(!CoderPadRetryPolicy.isTransient(CoderPadError.missingAPIKey))
        #expect(!CoderPadRetryPolicy.isTransient(CoderPadError.decode("no")))
        #expect(!CoderPadRetryPolicy.isTransient(URLError(.cancelled)))
    }
}

@Suite("Raw Interview API error mapping")
struct RawAPINetworkMappingTests {
    @Test
    func `transport failures become CoderPadError network`() async {
        RawTransportFailureURLProtocol.reset(error: URLError(.timedOut))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RawTransportFailureURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "key",
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await client.rawRequest(path: "/api/quota", responseLimit: 1024)
            Issue.record("Expected a mapped network failure")
        } catch let error as CoderPadError {
            guard case let .network(urlError) = error else {
                Issue.record("Expected CoderPadError.network, got \(error)")
                return
            }
            #expect(urlError.code == .timedOut)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("Screen GET retries", .serialized)
struct ScreenGETRetryTests {
    @Test
    func `listCampaigns retries a transient 503 then succeeds`() async throws {
        ScreenTransientRetryURLProtocol.reset(failuresBeforeSuccess: 2, status: 503)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScreenTransientRetryURLProtocol.self]
        let client = ScreenClient(
            apiKey: "retry-key",
            baseURL: ScreenClient.mockBaseURL,
            session: URLSession(configuration: configuration)
        )

        let campaigns = try await client.listCampaigns()
        #expect(campaigns.count == 1)
        #expect(ScreenTransientRetryURLProtocol.attemptCount() == 3)
    }

    @Test
    func `mutating Screen requests are not retried`() async {
        ScreenTransientRetryURLProtocol.reset(failuresBeforeSuccess: 2, status: 503)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScreenTransientRetryURLProtocol.self]
        let client = ScreenClient(
            apiKey: "retry-key",
            baseURL: ScreenClient.mockBaseURL,
            session: URLSession(configuration: configuration)
        )

        await #expect(throws: CoderPadError.self) {
            try await client.cancelTest(id: 1)
        }
        #expect(ScreenTransientRetryURLProtocol.attemptCount() == 1)
    }
}

private final nonisolated class AuthorizationCaptureURLProtocol: URLProtocol {
    private static let captured = Mutex<String?>(nil)

    static func reset() {
        captured.withLock { $0 = nil }
    }

    static func capturedAuthorization() -> String? {
        captured.withLock { $0 }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.captured.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"pads_used":1,"pads_remaining":1}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final nonisolated class RawTransportFailureURLProtocol: URLProtocol {
    private static let failure = Mutex<URLError>(URLError(.timedOut))

    static func reset(error: URLError) {
        failure.withLock { $0 = error }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: Self.failure.withLock { $0 })
    }

    override func stopLoading() {}
}

private final nonisolated class ScreenTransientRetryURLProtocol: URLProtocol {
    private struct State: Sendable {
        var failuresBeforeSuccess: Int
        var status: Int
        var attempts: Int
    }

    private static let state = Mutex(State(failuresBeforeSuccess: 0, status: 503, attempts: 0))

    static func reset(failuresBeforeSuccess: Int, status: Int) {
        state.withLock {
            $0 = State(failuresBeforeSuccess: failuresBeforeSuccess, status: status, attempts: 0)
        }
    }

    static func attemptCount() -> Int {
        state.withLock(\.attempts)
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let attempt = Self.state.withLock { state -> Int in
            state.attempts += 1
            return state.attempts
        }
        let (failuresBeforeSuccess, status) = Self.state.withLock {
            ($0.failuresBeforeSuccess, $0.status)
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if attempt <= failuresBeforeSuccess {
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(#"{"message":"unavailable"}"#.utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let body: Data
        if request.httpMethod?.uppercased() == "GET" {
            body = Data(#"[{"id":1,"name":"Retry Campaign","languages":["swift"]}]"#.utf8)
        } else {
            body = Data()
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: request.httpMethod?.uppercased() == "GET" ? 200 : 204,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
