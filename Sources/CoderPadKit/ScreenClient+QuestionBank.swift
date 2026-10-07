import Foundation

public nonisolated extension ScreenClient {
    /// One offset page of UUID question summaries. Filters preserve false and zero values.
    func listQuestions(filters: ScreenQuestionFilters = ScreenQuestionFilters(),
                       start: Int? = nil, limit: Int? = nil) async throws -> ScreenQuestionsPage {
        if let start { try Self.requirePaginationStart(start) }
        if let limit, !(1 ... Self.maximumPageSize).contains(limit) {
            throw CoderPadError.decode("Screen question page size must be between 1 and 50.")
        }
        var query = filters.queryItems
        if let start { query.append(URLQueryItem(name: "start", value: String(start))) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await get(ScreenQuestionsPage.self, path: "/questions", query: query)
    }

    /// Follows advancing offsets while preserving all filters, bounded like full test-session lists.
    func listAllQuestions(filters: ScreenQuestionFilters = ScreenQuestionFilters(),
                          start: Int = 0, limit: Int = Self.maximumPageSize) async throws -> [ScreenQuestionSummary] {
        var current = start
        var result: [ScreenQuestionSummary] = []
        for _ in 0 ..< Self.maximumFullListPages {
            let page = try await listQuestions(filters: filters, start: current, limit: limit)
            guard page.questions.count <= Self.maximumFullListItems - result.count else {
                throw CoderPadError.decode("Screen question listing exceeded the item limit.")
            }
            result.append(contentsOf: page.questions)
            guard page.pagination?.hasMoreItems == true else { return result }
            guard let next = page.pagination?.nextStart, next > current else {
                throw CoderPadError.decode("Screen question pagination did not advance.")
            }
            current = next
        }
        throw CoderPadError.decode("Screen question listing exceeded the page limit.")
    }

    /// Full details for a Screen UUID question, separate from Interview integer identities.
    func getQuestion(id: UUID) async throws -> ScreenQuestionDetails {
        try await get(ScreenQuestionDetails.self, path: "/questions/\(id.uuidString.lowercased())")
    }

    /// Creates a question with one request and retains the optional Location header.
    func createQuestion(_ question: ScreenQuestionSave) async throws -> ScreenCreatedQuestion {
        var request = try authorizedRequest(path: "/questions", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(question)
        let (body, response) = try await data(for: request)
        return ScreenCreatedQuestion(question: try decode(ScreenQuestionDetails.self, from: body),
                                     location: response.value(forHTTPHeaderField: "Location"))
    }

    /// Sends writable fields with PUT. Server-owned response blocks are absent from the save model.
    func updateQuestion(id: UUID, _ question: ScreenQuestionSave) async throws -> ScreenQuestionDetails {
        var request = try authorizedRequest(path: "/questions/\(id.uuidString.lowercased())", method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(question)
        return try await decode(ScreenQuestionDetails.self, from: data(for: request).0)
    }
}
