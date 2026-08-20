//
//  MockServer.swift
//  CoderPadKit
//
//  In-process URLProtocol that fakes the CoderPad API with canned data,
//  so the app can run in a demo mode without a real key or network.
//

import Foundation
import Synchronization

/// An in-process fake of the CoderPad API, served over `URLProtocol` with canned
/// fixtures, so an app can run in a demo mode and tests can run with no real key or
/// network. Pair it with ``CoderPadKit/CoderPadClient/mock(unauthorized:key:)``.
public nonisolated enum MockServer {
    static let host = "app.coderpad.io"
    static let historyHost = "coderpad-1.firebaseio.com"

    /// Only the canonical HTTPS Interview REST and Firebase history origins are
    /// intercepted. HTTP or a non-default port must fall through so misconfigured
    /// base URLs surface as transport failures (#187).
    static func handles(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              // Default HTTPS port only: an explicit non-443 port is not the live origin.
              url.port == nil || url.port == 443
        else { return false }

        return host == Self.host || host == Self.historyHost
    }

    /// A session backed by the in-process fake API. When `unauthorized` is true the
    /// server answers Interview REST requests with 401, which drives the "bad key" demo:
    /// the unauthorized banner and error states can be shown without a real revoked key.
    /// Firebase history remains available: those URLs carry no Interview bearer token.
    public static func session(unauthorized: Bool = false) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        let proto: URLProtocol.Type = unauthorized ? MockUnauthorizedURLProtocol.self : MockURLProtocol.self
        config.protocolClasses = [proto] + (config.protocolClasses ?? [])
        return URLSession(configuration: config)
    }

    /// Drops the Interview mock store for `key` so memory can be reclaimed (#138).
    public static func resetState(forKey key: String) {
        MockStateRegistry.removeState(forKey: key)
    }
}

/// Answers every Interview REST request with 401 Unauthorized, mimicking a revoked
/// or invalid API key. Backs the "bad key" demo account.
///
/// Firebase history requests are routed through the normal mock instead: the live
/// editor-history fetch intentionally carries no Interview bearer token (it's a
/// public Firebase URL), so an invalid Interview API key has no bearing on it. 401ing
/// it here would make an otherwise public URL look authenticated.
final nonisolated class MockUnauthorizedURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        MockServer.handles(request)
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.host == MockServer.historyHost {
            MockURLProtocol.serve(request: request, url: url, client: client, protocolInstance: self)
            return
        }

        let body = Data(#"{"status":"error","message":"Invalid API key"}"#.utf8)
        let headers = ["Content-Type": "application/json"]
        guard let response = HTTPURLResponse(
            url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final nonisolated class MockURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        MockServer.handles(request)
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.serve(request: request, url: url, client: client, protocolInstance: self)
    }

    override func stopLoading() {}

    /// Routes `request` through the fake API and replays the response onto
    /// `client`. Shared with `MockUnauthorizedURLProtocol`, which delegates its
    /// Firebase-history requests here instead of 401ing them: those requests carry
    /// no Interview bearer token even on the live API, so an invalid Interview key
    /// has no bearing on them.
    static func serve(
        request: URLRequest,
        url: URL,
        client: (any URLProtocolClient)?,
        protocolInstance: URLProtocol
    ) {
        let path = url.path
        let method = request.httpMethod ?? "GET"
        let bodyData = request.httpBody ?? Self.drain(stream: request.httpBodyStream)
        let contentType = request.value(forHTTPHeaderField: "Content-Type")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value } ?? [:]

        // Route to the per-API-key state (carried in the Authorization header the
        // client sets on every request), so each client - the app's demo account,
        // and each test - sees an isolated store.
        let state = MockStateRegistry.state(forKey: Self.apiKey(from: request))
        let (status, body) = MockResponses.respond(state: state,
                                                   method: method,
                                                   host: url.host,
                                                   path: path,
                                                   query: query,
                                                   body: bodyData,
                                                   contentType: contentType)

        let headers = ["Content-Type": "application/json"]
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
        ) else {
            client?.urlProtocol(protocolInstance, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(protocolInstance, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(protocolInstance, didLoad: body)
        client?.urlProtocolDidFinishLoading(protocolInstance)
    }

    /// The API key from the request's `Authorization: Bearer <key>` header, used to
    /// pick the request's `MockState`. Falls back to "demo" when absent so a stray
    /// unauthenticated request still resolves to a valid store.
    private static func apiKey(from request: URLRequest) -> String {
        let header = request.value(forHTTPHeaderField: "Authorization") ?? ""
        let key = header.hasPrefix("Bearer ") ? String(header.dropFirst("Bearer ".count)) : header
        return key.isEmpty ? "demo" : key
    }

    private static func drain(stream: InputStream?) -> Data? {
        MockRequestBody.drain(stream: stream)
    }
}
