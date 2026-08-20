//
//  TolerantJSON.swift
//  CoderPadKit
//
//  Element-level tolerant JSON array decoding and shared discard helpers used by
//  Interview response models (pads, questions, environments).
//

import Foundation

/// A tolerantly decoded JSON array: malformed elements are skipped rather than
/// failing the whole value, so one bad item can't hide every valid sibling.
nonisolated struct TolerantJSONList<Element: Decodable>: Decodable {
    let elements: [Element]
    let discardedCount: Int

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        var discardedCount = 0
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else if (try? container.decode(DiscardedJSONValue.self)) == nil {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: container.codingPath,
                    debugDescription: "JSON list contained an unreadable value."
                ))
            } else {
                discardedCount += 1
            }
        }
        elements = decoded
        self.discardedCount = discardedCount
    }
}

/// Advances a decoder past one JSON value so tolerant array decoding can skip a
/// malformed element without abandoning the rest of the array.
nonisolated struct DiscardedJSONValue: Decodable {
    private static let maximumNestingDepth = 64

    init(from decoder: any Decoder) throws {
        guard decoder.codingPath.count <= Self.maximumNestingDepth else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Discarded JSON value exceeded the nesting limit."
            ))
        }

        if var array = try? decoder.unkeyedContainer() {
            while !array.isAtEnd {
                _ = try array.decode(Self.self)
            }
            return
        }

        if let object = try? decoder.container(keyedBy: DiscardedJSONCodingKey.self) {
            for key in object.allKeys {
                _ = try object.decode(Self.self, forKey: key)
            }
            return
        }

        _ = try? decoder.singleValueContainer()
    }
}

private nonisolated struct DiscardedJSONCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// An `Int` that must be strictly positive. Used for resource identities and for
/// tolerant ID lists where nonpositive values are treated as malformed elements.
nonisolated struct PositiveInt: Decodable, Hashable, Sendable {
    let value: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        guard raw > 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a positive integer."
            )
        }
        value = raw
    }
}

/// An `Int` that must not be negative. Used for counts and usage metrics.
nonisolated struct NonnegativeInt: Decodable, Hashable, Sendable {
    let value: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        guard raw >= 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a nonnegative integer."
            )
        }
        value = raw
    }
}

extension KeyedDecodingContainer {
    /// Decodes an array element-by-element. A missing key yields an empty list.
    /// Malformed elements are skipped and counted. A wrong-shaped value (not an
    /// array) is logged and treated as empty, matching pad-environment
    /// `file_contents` tolerance.
    nonisolated func decodeTolerantArrayIfPresent<Element: Decodable>(
        _: Element.Type,
        forKey key: Key
    ) -> (elements: [Element], omittedCount: Int) {
        guard contains(key) else {
            return ([], 0)
        }

        do {
            let list = try decode(TolerantJSONList<Element>.self, forKey: key)
            return (list.elements, list.discardedCount)
        } catch {
            apiLogger.debug(
                """
                decodeIfPresent '\(key.stringValue)' \
                as [\(String(describing: Element.self))] \
                failed: \(error.localizedDescription)
                """
            )
            return ([], 0)
        }
    }

    /// Like ``loggedDecodeIfPresent`` for a positive `Int`, omitting nonpositive
    /// values with a decode diagnostic rather than failing the parent model.
    nonisolated func loggedDecodePositiveIntIfPresent(forKey key: Key) -> Int? {
        loggedDecodeIfPresent(PositiveInt.self, forKey: key)?.value
    }

    /// Like ``loggedDecodeIfPresent`` for a nonnegative `Int`, omitting negatives
    /// with a decode diagnostic rather than failing the parent model.
    nonisolated func loggedDecodeNonnegativeIntIfPresent(forKey key: Key) -> Int? {
        loggedDecodeIfPresent(NonnegativeInt.self, forKey: key)?.value
    }
}

nonisolated func omittedJSONElementsDiagnostic(
    count: Int,
    singular: String,
    plural: String
) -> String? {
    guard count > 0 else { return nil }

    let noun = count == 1 ? singular : plural
    return "Ignored \(count) malformed \(noun)."
}
