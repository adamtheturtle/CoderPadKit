//
//  ScreenAPI+Dates.swift
//  coderpad
//

import Foundation

public nonisolated enum ScreenEpochMilliseconds {
    public static let earliest = 946_684_800_000 // 2000-01-01T00:00:00Z
    public static let latest = 4_102_444_800_000 // 2100-01-01T00:00:00Z

    public static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Int? {
        guard let value = try container.decodeIfPresent(Int.self, forKey: key) else { return nil }
        guard (earliest ... latest).contains(value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Screen timestamp is outside the supported 2000–2100 range."
            )
        }

        return value
    }

    public static func date(from value: Int?) -> Date? {
        guard let value, (earliest ... latest).contains(value) else { return nil }

        return Date(timeIntervalSince1970: Double(value) / 1000)
    }
}

public extension ScreenTestSession {
    public var sendDate: Date? {
        ScreenEpochMilliseconds.date(from: sendTime)
    }

    public var startDate: Date? {
        ScreenEpochMilliseconds.date(from: startTime)
    }

    public var endDate: Date? {
        ScreenEpochMilliseconds.date(from: endTime)
    }

    public var lastActivityDate: Date? {
        ScreenEpochMilliseconds.date(from: lastActivityTime)
    }

    /// Recruiter dashboard URL when the API value is absolute HTTPS without
    /// credentials (#167).
    public var openableURL: URL? {
        OpenableHTTPSURL.parse(url)
    }

    /// Candidate test URL when the API value is absolute HTTPS without
    /// credentials (#167).
    public var openableTestURL: URL? {
        OpenableHTTPSURL.parse(testURL)
    }
}

public extension ScreenInvitationResult {
    /// Candidate invitation URL when the API value is absolute HTTPS without
    /// credentials (#167).
    public var openableTestURL: URL? {
        OpenableHTTPSURL.parse(testURL)
    }
}

extension ScreenTestSession {
    /// Rejects jointly present timestamps that cannot describe a real session
    /// lifecycle (negative durations, activity outside the window) (#169).
    nonisolated static func validateChronology(
        sendTime: Int?,
        startTime: Int?,
        endTime: Int?,
        lastActivityTime: Int?,
        codingPath: [any CodingKey]
    ) throws {
        if let sendTime, let startTime, startTime < sendTime {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Screen start_time must not precede send_time."
            ))
        }
        if let startTime, let endTime, endTime < startTime {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Screen end_time must not precede start_time."
            ))
        }
        if let sendTime, let endTime, endTime < sendTime {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Screen end_time must not precede send_time."
            ))
        }
        if let lastActivityTime {
            if let sendTime, lastActivityTime < sendTime {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Screen last_activity_time must not precede send_time."
                ))
            }
            if let endTime, lastActivityTime > endTime {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "Screen last_activity_time must not follow end_time."
                ))
            }
        }
    }
}
