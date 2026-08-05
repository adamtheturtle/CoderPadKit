//
//  PadHistoryURLPolicy.swift
//  CoderPadKit
//

import Foundation
import SafeURLKit

/// The origins from which CoderPad editor history may be fetched.
///
/// History URLs are API data rather than trusted configuration. Restricting them here
/// prevents a compromised endpoint from turning a client into a probe for localhost,
/// private services, or cloud metadata. The network transport additionally refuses any
/// redirect that leaves the initially validated origin.
public nonisolated enum PadHistoryURLPolicy {
    private static let trustedOrigins = [
        "https://app.coderpad.io",
        "https://eu.app.coderpad.io",
        "https://coderpad-prod.europe-west1.firebasedatabase.app"
    ]

    private static let trustedOriginPolicy = URLPolicy(
        allowedSchemes: ["https"],
        allowedOrigins: trustedOrigins.compactMap(OriginRule.origin(matching:)),
        portRule: .defaultForScheme
    )

    /// Returns whether `urlString` is an HTTPS history URL on a supported production
    /// origin or exactly the configured account origin.
    public static func isAllowed(_ urlString: String, accountBaseURL: URL) -> Bool {
        if trustedOriginPolicy.allows(urlString) {
            return true
        }
        if firebaseShardPolicy(for: urlString)?.allows(urlString) == true {
            return true
        }
        return accountPolicy(for: accountBaseURL)?.allows(urlString) ?? false
    }

    /// Legacy Firebase databases use `coderpad-N.firebaseio.com`, where N is a positive
    /// decimal shard. Construct an exact-origin policy only after recognizing that full
    /// namespace, instead of granting every Firebase project fetch authority.
    private static func firebaseShardPolicy(for urlString: String) -> URLPolicy? {
        guard let host = URLComponents(string: urlString)?.host?.lowercased(),
              host.hasPrefix("coderpad-"), host.hasSuffix(".firebaseio.com")
        else { return nil }

        let shardStart = host.index(host.startIndex, offsetBy: "coderpad-".count)
        let shardEnd = host.index(host.endIndex, offsetBy: -".firebaseio.com".count)
        let shard = host[shardStart ..< shardEnd]
        guard let first = shard.first, first != "0",
              shard.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let parsedHost = try? URLHost.parse(host)
        else { return nil }

        return URLPolicy(
            allowedSchemes: ["https"],
            allowedOrigins: [.origin(scheme: "https", host: parsedHost, port: nil)],
            portRule: .defaultForScheme
        )
    }

    /// Self-hosted history is accepted only on the configured account's exact HTTPS
    /// origin. Reserved domain names are permitted for this one explicit origin, while
    /// IP literals and reserved address ranges remain rejected.
    private static func accountPolicy(for accountBaseURL: URL) -> URLPolicy? {
        guard let components = URLComponents(url: accountBaseURL, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(), !host.isEmpty,
              let parsedHost = try? URLHost.parse(host)
        else { return nil }

        let configuredScheme = components.scheme?.lowercased()
        let port = components.port ?? (configuredScheme == "http" ? 80 : 443)
        return URLPolicy(
            allowedSchemes: ["https"],
            allowedOrigins: [.origin(scheme: "https", host: parsedHost, port: port)],
            portRule: .allowed([port]),
            allowsSpecialUseHostNames: true
        )
    }
}
