import CoderPadKit
import Foundation

nonisolated extension MockResponses {
    static func applyProjectPadFiles(_ create: PadCreate, language: String,
                                     environment: inout [String: Any]) -> (Int, Data)? {
        guard InterviewLanguage.projectIdentifiers.contains(language) else { return nil }
        var project: [String: Any] = ["language": language]
        var params: [String: Any] = [:]
        if let files = create.fileContents,
           let data = try? JSONEncoder().encode(files),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            params["file_contents"] = decoded
        }
        if let error = applyParentFiles(params, to: &project, creating: true) {
            return error
        }
        environment["file_contents"] = project["file_contents"] ?? []
        return nil
    }

    static func normalizeProjectPad(_ pad: inout [String: Any], language: String) {
        guard InterviewLanguage.projectIdentifiers.contains(language) else { return }
        pad["language"] = NSNull()
        pad["contents"] = NSNull()
    }
}
