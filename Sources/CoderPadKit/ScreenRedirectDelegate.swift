//
//  ScreenRedirectDelegate.swift
//  CoderPadKit
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Keeps Screen credentials on the origin for which the request was built.
///
/// Returning `nil` leaves the redirect response as the task's final response. The
/// normal response mapping then surfaces it as an HTTP error without contacting the
/// cross-origin target or forwarding the `API-Key` header.
final nonisolated class ScreenRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private struct Origin: Equatable {
        let scheme: String
        let host: String
        let port: Int
    }

    private let requestOrigin: URL?

    init(requestURL: URL?) {
        requestOrigin = requestURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(Self.hasSameOrigin(requestOrigin, request.url) ? request : nil)
    }

    static func hasSameOrigin(_ first: URL?, _ second: URL?) -> Bool {
        guard let first = originComponents(first), let second = originComponents(second) else { return false }
        return first == second
    }

    private static func originComponents(_ url: URL?) -> Origin? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil,
              components.password == nil,
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              let port = components.port ?? defaultPort(for: scheme)
        else { return nil }
        return Origin(scheme: scheme, host: host, port: port)
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "http": 80
        case "https": 443
        default: nil
        }
    }
}
