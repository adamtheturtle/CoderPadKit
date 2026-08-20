//
//  APIKeyNormalization.swift
//  CoderPadKit
//
//  Shared Interview and Screen credential scrubbing so every request path uses the
//  same validated key (#157, #161).
//

import Foundation

enum APIKeyNormalization {
    /// Trims surrounding whitespace/newlines and accepts only printable ASCII (no
    /// spaces or control bytes). Returns `nil` when the result would be empty or
    /// unsafe to place in an Authorization / API-Key header.
    nonisolated static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.allSatisfy({ (0x21 ... 0x7E).contains($0) })
        else { return nil }
        return trimmed
    }
}
