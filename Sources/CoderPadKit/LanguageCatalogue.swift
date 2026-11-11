import Foundation

public extension CoderPadClient {
    /// Retrieves all available environments, preserving the complete catalogue metadata.
    func listLanguages() async throws -> JSONValue {
        try await rest.fetch(JSONValue.self, path: "/api/languages")
    }

    /// Retrieves starter code and environment context before authoring a project.
    func getLanguage(_ identifier: String) async throws -> JSONValue {
        guard !identifier.isEmpty,
              identifier.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            throw CoderPadError.decode("Language must be an environment identifier.")
        }
        return try await rest.fetch(JSONValue.self, path: "/api/languages/\(identifier)")
    }
}
