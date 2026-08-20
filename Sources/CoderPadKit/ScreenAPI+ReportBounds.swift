//
//  ScreenAPI+ReportBounds.swift
//  coderpad
//

import Foundation

/// Proctoring/anti-cheat warnings within a report. A single null or
/// wrong-typed element is skipped rather than invalidating the whole report
/// (#218); `discardedCount` tracks how many elements were dropped.
nonisolated struct BoundedScreenWarnings: Decodable {
    private static let maximumEntries = 100
    private static let maximumLength = 500
    public let values: [String]
    public let discardedCount: Int

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [String] = []
        var discardedCount = 0
        decoded.reserveCapacity(min(container.count ?? 0, Self.maximumEntries))
        while !container.isAtEnd {
            guard let raw = try? container.decode(String.self) else {
                if (try? container.decode(DiscardedScreenValue.self)) == nil {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: container.codingPath,
                        debugDescription: "Screen report warnings contained an unreadable value."
                    ))
                }
                discardedCount += 1
                continue
            }

            let normalized = raw.components(separatedBy: .controlCharacters)
                .joined(separator: " ")
                .split(whereSeparator: \Character.isWhitespace)
                .joined(separator: " ")
            guard !normalized.isEmpty else {
                discardedCount += 1
                continue
            }

            if decoded.count < Self.maximumEntries {
                decoded.append(String(normalized.prefix(Self.maximumLength)))
            } else {
                // Count excess genuine warnings so a full retained list is not
                // indistinguishable from a truncated one (#113).
                discardedCount += 1
            }
        }
        values = decoded
        self.discardedCount = discardedCount
    }
}
