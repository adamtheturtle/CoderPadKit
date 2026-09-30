import Foundation
import PaginatedRESTClient

public extension CoderPadClient {
    /// Lists the variants nested under a question.
    func listQuestionVariants(questionID: Int) async throws -> [QuestionVariant] {
        let path = try questionVariantsPath(questionID: questionID)
        return try await rest.fetch(QuestionVariantsResponse.self, path: path).variants
    }

    /// Fetches a single variant in the question's scope.
    func getQuestionVariant(questionID: Int, id: Int) async throws -> QuestionVariant {
        let path = try questionVariantsPath(questionID: questionID, id: id)
        return try await rest.fetch(QuestionVariant.self, path: path)
    }

    /// Creates a variant. The language may be a language key or project-template slug.
    func createQuestionVariant(questionID: Int, _ body: QuestionVariantMutation) async throws -> QuestionVariant {
        let path = try questionVariantsPath(questionID: questionID)
        guard body.language != nil else {
            throw EncodingError.invalidValue(body, .init(codingPath: [],
                                                         debugDescription: "Creating a variant requires a language."))
        }
        _ = try Self.makeEncoder().encode(body)
        return try await rest.send(QuestionVariant.self, method: "POST", path: path, body: body)
    }

    /// Updates supplied attributes and returns the variant from the mutation response.
    func updateQuestionVariant(questionID: Int, id: Int,
                               _ body: QuestionVariantMutation) async throws -> QuestionVariant {
        let path = try questionVariantsPath(questionID: questionID, id: id)
        _ = try Self.makeEncoder().encode(body)
        return try await rest.send(QuestionVariant.self, method: "PUT", path: path, body: body)
    }

    /// Deletes a variant, accepting either an empty or JSON success response.
    func deleteQuestionVariant(questionID: Int, id: Int) async throws {
        let path = try questionVariantsPath(questionID: questionID, id: id)
        guard !apiKey.isEmpty else { throw CoderPadError.missingAPIKey }
        let request = RESTRequest(url: baseURL.appending(path: path), method: "DELETE",
                                  headers: ["Authorization": "Bearer \(apiKey)", "Accept": "application/json"])
        try await rest.performNoContent(request: request)
    }

    private func questionVariantsPath(questionID: Int, id: Int? = nil) throws -> String {
        try Self.validatePositiveResourceID(questionID, kind: "question")
        if let id {
            try Self.validatePositiveResourceID(id, kind: "question variant")
        }
        return "/api/questions/\(questionID)/variants" + (id.map { "/\($0)" } ?? "")
    }
}
