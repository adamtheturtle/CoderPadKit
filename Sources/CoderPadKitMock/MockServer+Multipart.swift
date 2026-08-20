//
//  MockServer+Multipart.swift
//  CoderPadKitMock
//
//  Minimal multipart text-field decoding for question ZIP mutation fidelity.
//

import Foundation

nonisolated extension MockResponses {
    /// Reads either the client's JSON question body or its multipart text fields.
    /// The ZIP bytes themselves are deliberately ignored: the mock needs to preserve
    /// mutation semantics, not interpret archive contents.
    ///
    /// Returns `nil` for a missing, malformed, or wrong-shaped body so callers can
    /// reject the request without mutating state.
    static func questionParams(body: Data?, contentType: String?) -> [String: Any]? {
        guard let body, !body.isEmpty else { return nil }
        guard let contentType,
              contentType.hasPrefix("multipart/form-data;"),
              let boundary = contentType.components(separatedBy: "boundary=").last,
              !boundary.isEmpty else {
            guard let object = try? JSONSerialization.jsonObject(with: body),
                  let dict = object as? [String: Any] else { return nil }
            return flattenQuestionParams(dict)
        }

        let raw = String(decoding: body, as: UTF8.self)
        let openingBoundary = "--\(boundary)\r\n"
        let closingBoundary = "\r\n--\(boundary)--"
        guard raw.hasPrefix(openingBoundary),
              let closingRange = raw.range(of: closingBoundary, options: .backwards),
              closingRange.upperBound == raw.endIndex
                  || raw[closingRange.upperBound...] == "\r\n" else { return nil }

        let framedBody = String(raw[..<closingRange.lowerBound])
        var fields: [String: Any] = [:]
        var seenNames: Set<String> = []
        for part in framedBody.components(separatedBy: openingBoundary) {
            guard let split = part.range(of: "\r\n\r\n") else { continue }
            let headers = String(part[..<split.lowerBound])
            guard let nameStart = headers.range(of: "name=\"")?.upperBound,
                  let nameEnd = headers[nameStart...].firstIndex(of: "\"") else { continue }

            let wireName = String(headers[nameStart ..< nameEnd])
            let name = wireName.hasPrefix("question[") && wireName.hasSuffix("]")
                ? String(wireName.dropFirst("question[".count).dropLast())
                : wireName
            guard seenNames.insert(name).inserted else { return nil }
            guard !headers.contains("filename=") else { continue }

            var value = String(part[split.upperBound...])
            // Swift treats CRLF as one extended grapheme cluster, so one removal
            // drops the delimiter without eating the field's final character.
            if value.hasSuffix("\r\n") { value.removeLast() }
            fields[name] = multipartValue(value, name: name)
        }
        return fields
    }

    /// The JSON request nests `title`/`language` under a `question` object. Lift
    /// those back to top level so both wire encodings feed the same mock fixtures.
    private static func flattenQuestionParams(_ dict: [String: Any]) -> [String: Any] {
        guard let nested = dict["question"] as? [String: Any] else { return dict }

        var flattened = dict
        flattened.removeValue(forKey: "question")
        for (key, value) in nested {
            flattened[key] = value
        }
        return flattened
    }

    /// Coerce only known boolean multipart fields. Literal `"true"`/`"false"` in a
    /// text field such as `title` must stay strings.
    private static func multipartValue(_ value: String, name: String) -> Any {
        if name == "take_home" {
            if value == "true" { return true }
            if value == "false" { return false }
        }
        if name == "candidate_instructions",
           let data = value.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            return object
        }
        return value
    }
}
