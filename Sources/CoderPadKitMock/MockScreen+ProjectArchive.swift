import Foundation

nonisolated extension MockScreenResponses {
    private static let archiveRoute = regex(#"^/tests/(\d+)/questions/[a-fA-F0-9-]+/project/?$"#)

    static func projectArchiveRoute(state: MockScreenState, method: String, route: String) -> Result? {
        guard method == "GET", let rawID = match(route, archiveRoute), let id = Int(rawID) else { return nil }
        guard let test = state.allTests().first(where: { $0["id"] as? Int == id }),
              route.split(separator: "/").dropFirst(3).first.map(String.init)?.lowercased()
                == MockScreenFixtures.archiveQuestionID else {
            return json(404, ["code": "question_not_found", "message": "Project question not found"])
        }
        guard test["status"] as? String == "completed" else {
            return json(400, ["code": "project_unavailable", "message": "Project archive is not available"])
        }
        return Result(status: 200, body: MockScreenFixtures.projectArchive, contentType: "application/gzip")
    }
}

nonisolated extension MockScreenFixtures {
    static let archiveQuestionID = "4143ca74-2f0e-4151-90d6-e1428739450b"
    /// A deterministic archive containing `src/answer.txt` with synthetic candidate changes.
    static let projectArchive = Data(base64Encoded:
        "H4sIAAAAAAAC/+3NMQ6DMBBE0a1zCk5ANgh8AU6yAgtoXNhG5PhxaCLREwnxXzOjaSbF4WkhbT7W+Z3l" +
        "FFq4tt2zOKZq0/z6d39p55xUKn+wpmyx3Ms99RbGZbTsq2G2MPn0EAAAAAAAAAAAAAAAAADABXwAWo/5" +
        "UQAoAAA="
    )!
}
