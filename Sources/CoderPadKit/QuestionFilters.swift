import Foundation

/// Usage categories accepted by the Interview question library.
public nonisolated enum QuestionPadType: String, CaseIterable, Hashable, Sendable {
    case any
    case live
    case takeHome = "take_home"
}

/// Question sorting includes title and usage count, separate from pad sorting.
public nonisolated enum InterviewQuestionSort: String, CaseIterable, Hashable, Sendable {
    case createdAtAsc = "created_at,asc"
    case createdAtDesc = "created_at,desc"
    case updatedAtAsc = "updated_at,asc"
    case updatedAtDesc = "updated_at,desc"
    case titleAsc = "title,asc"
    case titleDesc = "title,desc"
    case usedAsc = "used,asc"
    case usedDesc = "used,desc"

    /// Normalizes a combined field and direction, preserving the API default.
    public static func validated(_ sort: String?) throws -> String? {
        guard let sort else { return nil }
        let value = sort.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: ",")
        guard let result = Self(rawValue: value) else {
            throw CoderPadError.decode(
                "Question sort must be created_at|updated_at|title|used with direction asc|desc."
            )
        }
        return result.rawValue
    }
}

nonisolated enum QuestionFilters {
    static func personal(text: String?, padTypes: [QuestionPadType]?) -> String {
        var items = padTypes?.map { URLQueryItem(name: "pad_types[]", value: $0.rawValue) } ?? []
        if let text { items.append(URLQueryItem(name: "text", value: text)) }
        return path("/api/questions/", items: items)
    }

    static func organization(padType: InterviewType?, language: String?) -> String {
        var items: [URLQueryItem] = []
        if let padType {
            items.append(URLQueryItem(name: "pad_type", value: padType == .takeHome ? "take_home" : "live"))
        }
        if let language { items.append(URLQueryItem(name: "language", value: language)) }
        return path("/api/organization/questions", items: items)
    }

    private static func path(_ path: String, items: [URLQueryItem]) -> String {
        guard !items.isEmpty else { return path }
        var components = URLComponents()
        components.path = path
        components.queryItems = items
        // Form query decoding treats literal plus signs as spaces.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.string ?? path
    }
}
