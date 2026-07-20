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
}
