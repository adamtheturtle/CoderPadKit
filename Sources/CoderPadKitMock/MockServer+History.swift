//
//  MockServer+History.swift
//  CoderPadKit
//
//  The fake API's Firebase history routes. CoderPad serves editor history from
//  `coderpad-N.firebaseio.com` rather than from the REST API, on two distinct kinds
//  of node: the per-file node a `PadEnvironmentFile.history` points at, and the
//  pad-level node a `Pad.history` points at. Both are routed here, split out of
//  MockServer+Responses.swift so each file stays within the line and body-length
//  limits.
//

import Foundation

nonisolated extension MockResponses {
    /// Routes the Firebase history hosts. Checked ahead of the REST routes because
    /// these paths are rooted at the Firebase host, not under `/api`.
    static func historyRoute(state: MockState, method: String, path: String) -> (Int, Data)? {
        guard method == "GET" else { return nil }

        if let (environmentID, fileIndex) = fileHistoryLocation(path) {
            guard let history = MockFixtures.padHistory(
                environmentID: environmentID, fileIndex: fileIndex
            ) else {
                return (404, jsonString(["error": "history not found"]))
            }
            return ok(history)
        }

        if let padID = padHistoryLocation(path) {
            return padLevelHistory(state: state, padID: padID)
        }

        return nil
    }

    /// Serves the Firebase node a pad's own `history` field points at.
    ///
    /// The live API really does hand out
    /// `https://coderpad-N.firebaseio.com/<padID>/history.json` on every pad, so the
    /// seeded URL is the faithful shape and it was the router that was missing:
    /// previously only the per-file `PadEnvironmentFile.history` URLs resolved, and a
    /// pad's own `history` 404ed even though the mock claimed the Firebase host.
    ///
    /// The pad-level node is served from the pad's active environment's first file,
    /// which is the editor buffer a single-file pad's history describes.
    private static func padLevelHistory(state: MockState, padID: String) -> (Int, Data) {
        guard let pad = state.allPads().first(where: { ($0["id"] as? String) == padID }) else {
            return (404, jsonString(["error": "history not found"]))
        }

        let environmentID = pad["active_environment_id"] as? Int
            ?? (pad["pad_environment_ids"] as? [Int])?.first
            ?? 1
        guard let history = MockFixtures.padHistory(environmentID: environmentID, fileIndex: 0) else {
            return (404, jsonString(["error": "history not found"]))
        }
        return ok(history)
    }

    /// The environment and file a per-file history path addresses, as seeded onto
    /// `PadEnvironmentFile.history`:
    /// `/mock/pad-environments/<environmentID>/files/<index>/history.json`.
    private static func fileHistoryLocation(_ path: String) -> (environmentID: Int, fileIndex: Int)? {
        let parts = path.split(separator: "/")
        guard parts.count == 6,
              parts[0] == "mock",
              parts[1] == "pad-environments",
              let environmentID = Int(parts[2]),
              parts[3] == "files",
              let fileIndex = Int(parts[4]),
              parts[5] == "history.json"
        else { return nil }

        return (environmentID, fileIndex)
    }

    /// The pad id in a pad-level history path, `/<padID>/history.json`. Two segments,
    /// so it can never shadow the six-segment per-file paths above.
    private static func padHistoryLocation(_ path: String) -> String? {
        let parts = path.split(separator: "/")
        guard parts.count == 2, parts[1] == "history.json", !parts[0].isEmpty else { return nil }

        return String(parts[0])
    }
}
