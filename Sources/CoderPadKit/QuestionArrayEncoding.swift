import Foundation

/// Parent-question writes carry instruction and file arrays as JSON strings.
nonisolated func encodedQuestionArray<Value: Encodable>(_ value: [Value]?) throws -> String? {
    guard let value else { return nil }
    return String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
}
