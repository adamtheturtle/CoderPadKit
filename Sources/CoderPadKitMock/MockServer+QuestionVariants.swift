import Foundation

nonisolated extension MockResponses {
    static func questionVariantRoute(state: MockState, method: String, path: String, body: Data?) -> (Int, Data)? {
        let parts = path.split(separator: "/")
        guard parts.count == 4 || parts.count == 5, parts[0] == "api", parts[1] == "questions",
              parts[3] == "variants" else { return nil }
        guard let questionID = Int(parts[2]), questionID > 0,
              state.allQuestions().contains(where: { $0["id"] as? Int == questionID })
        else {
            return variantError("Question not found.", status: 404)
        }
        let variants = state.questionVariants[questionID] ?? []
        if parts.count == 4 {
            if method == "GET" {
                return ok(["variants": variants])
            }
            if method == "POST" {
                return createVariant(state: state, questionID: questionID, body: body)
            }
            return variantError("Method not allowed.", status: 405)
        }
        guard let id = Int(parts[4]), let index = variants.firstIndex(where: { $0["id"] as? Int == id }) else {
            return variantError("Variant not found.", status: 404)
        }
        switch method {
        case "GET": return ok(variants[index])
        case "DELETE":
            state.questionVariants[questionID]?.remove(at: index)
            return (204, Data())
        case "PUT":
            return updateVariant(state: state, questionID: questionID, index: index, body: body)
        default: return variantError("Method not allowed.", status: 405)
        }
    }

    private static func createVariant(state: MockState, questionID: Int, body: Data?) -> (Int, Data) {
        guard let attributes = variantParams(body), let language = attributes["language"] as? String,
              !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return variantError("A language key or project-template slug is required.")
        }
        let now = Date.now.formatted(.iso8601)
        var variant: [String: Any] = [
            "id": state.nextQuestionVariantID, "question_id": questionID,
            "contents": NSNull(), "file_contents": NSNull(), "solution": NSNull(),
            "created_at": now, "updated_at": now
        ]
        configureEnvironment(&variant, language: language)
        if let error = applyVariantAttributes(attributes, to: &variant, creating: true) {
            return error
        }
        state.nextQuestionVariantID += 1
        state.questionVariants[questionID, default: []].append(variant)
        return ok(variant)
    }

    private static func updateVariant(state: MockState, questionID: Int, index: Int, body: Data?) -> (Int, Data) {
        guard let attributes = variantParams(body), var variant = state.questionVariants[questionID]?[index] else {
            return variantError("Expected a JSON object.")
        }
        if let language = attributes["language"] as? String, language != variant["language"] as? String {
            guard !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return variantError("Language must not be blank.")
            }
            configureEnvironment(&variant, language: language)
            variant["contents"] = NSNull()
            variant["file_contents"] = language == "react" ? demoTemplateFiles : NSNull()
        }
        if let error = applyVariantAttributes(attributes, to: &variant, creating: false) {
            return error
        }
        variant["updated_at"] = Date.now.formatted(.iso8601)
        state.questionVariants[questionID]?[index] = variant
        return ok(variant)
    }

    private static func configureEnvironment(_ variant: inout [String: Any], language: String) {
        variant["language"] = language
        variant["display"] = language == "react" ? "React" : language
        variant["project_template_id"] = language == "react" ? 1 : NSNull()
        variant["project_template_slug"] = language == "react" ? "react" : NSNull()
        if language == "react" {
            variant["file_contents"] = demoTemplateFiles
        }
    }

    /// Deliberately small demo template, independent of production template contents.
    private static var demoTemplateFiles: [[String: Any]] {
        [["path": ".cpad", "contents": "{}"], ["path": "src/App.jsx", "contents": "export default function App() {}"]]
    }

    private static func applyVariantAttributes(_ attributes: [String: Any], to variant: inout [String: Any],
                                               creating: Bool) -> (Int, Data)? {
        if attributes.keys.contains("contents"), attributes.keys.contains("file_contents") {
            return variantError("contents and file_contents cannot be combined.")
        }
        for key in ["contents", "solution"] where attributes[key] != nil {
            variant[key] = attributes[key]
        }
        guard let rawFiles = attributes["file_contents"] else { return nil }
        guard let files = decodedVariantFiles(rawFiles) else {
            return variantError("file_contents must be an array of files.")
        }
        let isTemplate = variant["project_template_slug"] is String
        var result = creating && isTemplate ? demoTemplateFiles : []
        if files.isEmpty, isTemplate {
            result = demoTemplateFiles
        }
        for file in files {
            let path = file["path"] as? String ?? ""
            if file["deleted"] as? Bool == true {
                if path == ".cpad" {
                    return variantError(".cpad cannot be deleted.")
                }
                result.removeAll { $0["path"] as? String == path }
            } else {
                result.removeAll { $0["path"] as? String == path }
                result.append(file)
            }
        }
        guard !result.isEmpty else { return variantError("At least one file must remain.") }
        if isTemplate, !result.contains(where: { $0["path"] as? String == ".cpad" }) {
            result.insert(demoTemplateFiles[0], at: 0)
        }
        variant["file_contents"] = result
        return nil
    }

    private static func decodedVariantFiles(_ raw: Any) -> [[String: Any]]? {
        let decoded: Any? = if let text = raw as? String {
            try? JSONSerialization.jsonObject(with: Data(text.utf8))
        } else {
            raw
        }
        guard let files = decoded as? [[String: Any]], files.allSatisfy({ $0["path"] is String }) else { return nil }
        return files
    }

    private static func variantParams(_ body: Data?) -> [String: Any]? {
        guard let body, let root = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return nil }
        return root["variant"] as? [String: Any] ?? root
    }

    private static func variantError(_ message: String, status: Int = 422) -> (Int, Data) {
        (status, jsonString(["status": "error", "message": message]))
    }
}
