//
//  ScreenDictionaryKey.swift
//  coderpad
//

import Foundation

nonisolated struct DynamicScreenCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Makes remote Screen technology/skill keys safe for rows, exports, and
/// accessibility labels. Canonical composition also makes equivalent spellings
/// collide predictably in the sorted decoder.
nonisolated func normalizedScreenDictionaryKey(_ raw: String) -> String? {
    let scrubbed = scrubbedScreenDisplayText(raw)
    let normalized = scrubbed.precomposedStringWithCanonicalMapping
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    guard !normalized.isEmpty else { return nil }

    return String(normalized.prefix(100))
}

/// Replaces control, format (including bidirectional overrides), surrogate,
/// private-use, and unassigned scalars with spaces so warning text and dictionary
/// keys cannot reorder surrounding UI (#170).
nonisolated func scrubbedScreenDisplayText(_ raw: String) -> String {
    String(raw.unicodeScalars.map { scalar -> Character in
        switch scalar.properties.generalCategory {
        case .control, .format, .privateUse, .surrogate, .unassigned:
            " "
        default:
            Character(scalar)
        }
    })
}
