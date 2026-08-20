//
//  ScreenAPI+Metrics.swift
//  coderpad
//

import Foundation

public nonisolated enum ScreenReportMetric {
    public static func nonnegativeInteger<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Int? {
        guard let value = try container.decodeIfPresent(Int.self, forKey: key) else { return nil }
        guard value >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Screen count, points, and duration metrics must not be negative."
            )
        }

        return value
    }

    public static func percentage<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Double? {
        guard let value = try container.decodeIfPresent(Double.self, forKey: key) else { return nil }
        guard value.isFinite, (0 ... 100).contains(value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Screen percentage must be between 0 and 100."
            )
        }

        return value
    }

    /// Rejects a part/total pair (points/total_points, duration/total_duration) where the
    /// part exceeds the total. Both sides are already known nonnegative by the time this
    /// runs; only the joint relationship remains to be checked (#222, #223).
    public static func requireAtMost<Key: CodingKey>(
        _ value: Int?,
        atMost total: Int?,
        forKey key: Key,
        in container: KeyedDecodingContainer<Key>,
        debugDescription: String
    ) throws {
        guard let value, let total, value > total else { return }

        throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: debugDescription)
    }

    private static let maximumCommunityStatBuckets = 100

    /// Score-distribution buckets from `withCommunityStats`. Rejects negatives and
    /// oversized arrays so report metrics stay coherent (#116).
    public static func decodeCommunityStats<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> [Int]? {
        guard let buckets = try container.decodeIfPresent([Int].self, forKey: key) else {
            return nil
        }
        guard buckets.count <= maximumCommunityStatBuckets else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: """
                Screen report community_stats must contain at most \
                \(maximumCommunityStatBuckets) buckets.
                """
            )
        }
        guard buckets.allSatisfy({ $0 >= 0 }) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Screen report community_stats buckets must not be negative."
            )
        }
        return buckets
    }
}
