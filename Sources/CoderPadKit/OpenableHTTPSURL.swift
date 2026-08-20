//
//  OpenableHTTPSURL.swift
//  CoderPadKit
//
//  Absolute HTTPS URLs safe to hand to open/share UI: no relative paths, no
//  non-web schemes, and no embedded credentials (#166, #167).
//

import Foundation
import SafeURLKit

/// Parses strings that are documented as openable web links into absolute HTTPS
/// `URL` values. Relative paths, `javascript:`, `file:`, and credential-bearing
/// URLs return `nil` rather than a value a caller might open.
public nonisolated enum OpenableHTTPSURL {
    private static let policy = URLPolicy(
        allowedSchemes: ["https"],
        portRule: .defaultForScheme,
        allowsCredentials: false,
        allowsFragment: true,
        allowsQuery: true,
        maximumLength: 2048
    )

    /// An absolute HTTPS URL with no embedded credentials, or `nil` when `raw`
    /// is absent, blank, or not safe to open.
    public static func parse(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (try? policy.validate(trimmed))?.url
    }
}
