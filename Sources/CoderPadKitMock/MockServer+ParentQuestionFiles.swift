import Foundation

nonisolated extension MockResponses {
    static func applyParentFiles(_ params: [String: Any], to question: inout [String: Any],
                                 creating: Bool) -> (Int, Data)? {
        let template = (question["language"] as? String) == "react"
        let defaults: [[String: Any]] = template ? [
            ["path": ".cpad", "contents": "{}"],
            ["path": "src/App.jsx", "contents": "export default function App() {}"]
        ] : []
        guard let raw = params["file_contents"] else {
            if creating, template { question["file_contents"] = defaults }
            return nil
        }
        guard let files = raw as? [[String: Any]] else { return parentFileError("Invalid file contents") }
        var result = creating ? defaults : (question["file_contents"] as? [[String: Any]] ?? defaults)
        for file in files {
            guard let path = file["path"] as? String else { return parentFileError("Missing file path") }
            if file["deleted"] as? Bool == true {
                guard path != ".cpad" else { return parentFileError(".cpad cannot be deleted") }
                if creating { result.removeAll { $0["path"] as? String == path } }
            } else {
                guard file["contents"] is String else { return parentFileError("Missing file contents") }
                result.removeAll { $0["path"] as? String == path }
                result.append(file)
            }
        }
        question["file_contents"] = result
        return nil
    }

    private static func parentFileError(_ message: String) -> (Int, Data) {
        (400, jsonString(["status": "ERROR", "message": message]))
    }
}
