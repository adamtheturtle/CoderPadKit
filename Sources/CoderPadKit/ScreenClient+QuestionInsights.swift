import Foundation

public nonisolated extension ScreenClient {
    /// Usage, answer frequencies, test-case success, and score distribution for a UUID question.
    func questionInsights(id: UUID, programmingLanguage: String? = nil) async throws -> ScreenQuestionInsights {
        let query = programmingLanguage.map { [URLQueryItem(name: "programming_language", value: $0)] } ?? []
        return try await get(ScreenQuestionInsights.self,
                             path: "/questions/\(id.uuidString.lowercased())/insights", query: query)
    }
}
