//
//  ScreenAPI+Identity.swift
//  coderpad
//

import Foundation

/// Inclusive upper bound for Screen primary IDs. The API documents these as
/// `integer`/`int32`, so values above `Int32.max` are outside the contract (#212).
public nonisolated let maximumScreenID = Int(Int32.max)

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
