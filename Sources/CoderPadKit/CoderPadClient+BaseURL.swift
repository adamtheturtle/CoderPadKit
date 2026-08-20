//
//  CoderPadClient+BaseURL.swift
//  CoderPadKit
//

import Foundation

public extension CoderPadClient {
    /// The standard hosted CoderPad endpoint, used when an account doesn't
    /// override it (e.g. a self-hosted or regional deployment).
    static let defaultBaseURL = URL(string: "https://app.coderpad.io") ?? URL(fileURLWithPath: "/")

    /// Whether `url` is safe to use as an Interview API origin: HTTPS, no embedded
    /// credentials, and no query/fragment that would contaminate every endpoint URL
    /// (#200, #201). A non-empty path is allowed so self-hosted deployments can sit
    /// under a reverse-proxy prefix.
    nonisolated static func isAllowedBaseURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host != nil
            && url.user == nil
            && url.password == nil
            && url.query == nil
            && url.fragment == nil
    }
}
