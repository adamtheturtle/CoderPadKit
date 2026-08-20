//
//  ScreenClient+BaseURL.swift
//  coderpad
//

import Foundation

public extension ScreenClient {
    nonisolated static let mockBaseURL = URL(string: "https://screen.mock.coderpad.io")!

    /// Production Screen origins accepted by ``live(apiKey:baseURL:)``. The in-process
    /// mock host is intentionally excluded so a live session cannot send a real API key
    /// to `screen.mock.coderpad.io` (#202).
    public nonisolated static func isAllowedProductionBaseURL(_ url: URL) -> Bool {
        isAllowedOrigin(url, hosts: [defaultBaseURL.host, euBaseURL.host])
    }

    /// Origins accepted for any Screen request, including the in-process mock transport.
    /// Prefer ``isAllowedProductionBaseURL(_:)`` when constructing a live client.
    public nonisolated static func isAllowedBaseURL(_ url: URL) -> Bool {
        isAllowedProductionBaseURL(url)
            || isAllowedOrigin(url, hosts: [mockBaseURL.host])
    }

    private nonisolated static func isAllowedOrigin(_ url: URL, hosts: [String?]) -> Bool {
        let allowedHosts = hosts.compactMap { $0?.lowercased() }
        return url.scheme?.lowercased() == "https"
            && url.host.map { allowedHosts.contains($0.lowercased()) } == true
            && url.port == nil && url.user == nil && url.password == nil
            && url.query == nil && url.fragment == nil
            && (url.path.isEmpty || url.path == "/")
    }
}
