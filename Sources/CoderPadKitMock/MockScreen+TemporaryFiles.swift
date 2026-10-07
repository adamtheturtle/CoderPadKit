import CoderPadKit
import Foundation

nonisolated extension MockScreenResponses {
    static func temporaryFileRoute(state: MockScreenState, method: String, route: String, body: Data?) -> Result? {
        guard method == "POST", route == "/temporary-file" else { return nil }
        guard (body?.count ?? 0) <= ScreenClient.maximumTemporaryFileBytes else {
            return json(400, ["code": "archive_too_large", "message": "Archive body is too large"])
        }
        let id = UUID().uuidString.lowercased()
        state.temporaryFileIDs.insert(id)
        return json(200, ["id": id])
    }
}
