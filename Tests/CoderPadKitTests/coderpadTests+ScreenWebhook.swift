//
//  coderpadTests+ScreenWebhook.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Screen webhook validation")
struct ScreenWebhookValidationTests {
    @Test(arguments: [
        "", "http://coderpad.io/hook", "https://localhost/hook",
        "https://127.0.0.1/hook", "https://user:secret@coderpad.io/hook",
        "https://coderpad.io/hook#fragment"
    ])
    func `setter rejects unsafe callback URLs before transport`(url: String) async {
        #expect(ScreenClient.normalizedWebhookURL(url) == nil)
        do {
            try await screenClient().setWebhookURL(url)
            Issue.record("Expected an unsafe webhook URL to throw")
        } catch let error as CoderPadError {
            #expect(error.description.contains("public HTTPS URL"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `setter trims a safe public HTTPS callback`() async throws {
        #expect(ScreenClient.normalizedWebhookURL("  https://coderpad.io/hook?token=1\n")
            == "https://coderpad.io/hook?token=1")
        try await screenClient().setWebhookURL("  https://coderpad.io/hook?token=1\n")
    }

    @Test
    func `getter validation accepts absence and normalizes a safe callback`() throws {
        #expect(try ScreenClient.validatedWebhookURL(nil) == nil)
        #expect(try ScreenClient.validatedWebhookURL(" https://coderpad.io/hook ")
            == "https://coderpad.io/hook")
    }

    @Test(arguments: ["", "not a URL", "http://coderpad.io", "https://localhost/hook"])
    func `getter validation rejects malformed server configuration`(url: String) {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.validatedWebhookURL(url)
        }
    }

    @Test
    func `mock getter returns nil before a webhook is configured and the URL after`() async throws {
        let client = ScreenClient.mock(key: "webhook-absent-\(UUID().uuidString)")
        #expect(try await client.webhookURL() == nil)
        try await client.setWebhookURL("https://coderpad.io/configured")
        #expect(try await client.webhookURL() == "https://coderpad.io/configured")
        try await client.deleteWebhook()
        #expect(try await client.webhookURL() == nil)
    }
}

@Suite("Screen webhook status contracts", .serialized)
struct ScreenWebhookStatusContractTests {
    @Test
    func `getter maps a documented 404 to nil rather than an HTTP error`() async throws {
        let client = webhookStatusClient(status: 404, body: Data(#"{"code":"NotFound"}"#.utf8))
        #expect(try await client.webhookURL() == nil)
    }

    @Test
    func `getter maps a documented 204 success to nil rather than a decode error`() async throws {
        let client = webhookStatusClient(status: 204, body: Data())
        #expect(try await client.webhookURL() == nil)
    }

    @Test
    func `getter still returns a configured callback from a 200 JSON body`() async throws {
        let client = webhookStatusClient(
            status: 200,
            body: Data(#"{"url":"https://coderpad.io/hook"}"#.utf8)
        )
        #expect(try await client.webhookURL() == "https://coderpad.io/hook")
    }
}

private nonisolated struct WebhookStatusResponse: Sendable {
    let status: Int
    let body: Data
}

private final nonisolated class WebhookStatusURLProtocol: URLProtocol {
    private static let stub = Mutex<WebhookStatusResponse?>(nil)

    static func install(status: Int, body: Data) {
        stub.withLock { $0 = WebhookStatusResponse(status: status, body: body) }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.stub.withLock { $0 }
        guard let stub, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private nonisolated func webhookStatusClient(status: Int, body: Data) -> ScreenClient {
    WebhookStatusURLProtocol.install(status: status, body: body)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WebhookStatusURLProtocol.self]
    return ScreenClient(
        apiKey: "webhook-status",
        baseURL: URL(string: "https://www.codingame.com")!,
        session: URLSession(configuration: configuration)
    )
}
