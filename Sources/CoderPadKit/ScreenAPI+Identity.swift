//
//  ScreenAPI+Identity.swift
//  coderpad
//

import Foundation

/// Inclusive upper bound for Screen primary IDs. The API documents these as
/// `integer`/`int32`, so values above `Int32.max` are outside the contract (#212).
public nonisolated let maximumScreenID = Int(Int32.max)

/// A Screen model constructed with values that violate the same invariants the
/// JSON decoder enforces (#140–#142).
public nonisolated enum ScreenModelValidationError: LocalizedError, Equatable, Sendable {
    /// A Screen primary ID was outside `1 ... maximumScreenID`.
    case invalidID(kind: String, value: Int)
    /// A campaign name was empty after trimming whitespace.
    case blankCampaignName
    /// A timestamp fell outside the supported 2000–2100 epoch-millisecond range.
    case invalidTimestamp(name: String, value: Int)
    /// A report metric violated a nonnegative / percentage / joint invariant.
    case invalidMetric(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidID(kind, value):
            "Screen \(kind) ID \(value) must be a positive int32."
        case .blankCampaignName:
            "Screen campaign name must not be blank."
        case let .invalidTimestamp(name, value):
            "Screen \(name) \(value) is outside the supported 2000–2100 range."
        case let .invalidMetric(detail):
            detail
        }
    }
}

nonisolated func validatedScreenID(
    _ id: Int,
    codingPath: [any CodingKey],
    kind: String
) throws -> Int {
    guard (1 ... maximumScreenID).contains(id) else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: codingPath,
            debugDescription: "Screen \(kind) ID must be a positive int32."
        ))
    }

    return id
}

/// Same bounds as ``validatedScreenID(_:codingPath:kind:)``, for public memberwise
/// construction that cannot throw `DecodingError` (#140, #141).
nonisolated func validatedScreenModelID(_ id: Int, kind: String) throws -> Int {
    guard (1 ... maximumScreenID).contains(id) else {
        throw ScreenModelValidationError.invalidID(kind: kind, value: id)
    }
    return id
}

extension ScreenEpochMilliseconds {
    /// Requires a present timestamp to fall in ``earliest``...``latest`` (#141).
    public static func validated(_ value: Int?, name: String) throws -> Int? {
        guard let value else { return nil }
        guard (earliest ... latest).contains(value) else {
            throw ScreenModelValidationError.invalidTimestamp(name: name, value: value)
        }
        return value
    }
}

extension ScreenReportMetric {
    /// Requires a present integer metric to be nonnegative (#142).
    public static func validatedNonnegative(_ value: Int?, name: String) throws -> Int? {
        guard let value else { return nil }
        guard value >= 0 else {
            throw ScreenModelValidationError.invalidMetric(
                "Screen \(name) must not be negative."
            )
        }
        return value
    }

    /// Requires a present percentage to be finite and in `0...100` (#142).
    public static func validatedPercentage(_ value: Double?, name: String) throws -> Double? {
        guard let value else { return nil }
        guard value.isFinite, (0 ... 100).contains(value) else {
            throw ScreenModelValidationError.invalidMetric(
                "Screen \(name) must be between 0 and 100."
            )
        }
        return value
    }

    /// Joint part/total check for public construction (#142).
    public static func requireAtMost(
        _ value: Int?,
        atMost total: Int?,
        name: String
    ) throws {
        guard let value, let total, value > total else { return }
        throw ScreenModelValidationError.invalidMetric(
            "Screen \(name) must not exceed its total."
        )
    }
}
