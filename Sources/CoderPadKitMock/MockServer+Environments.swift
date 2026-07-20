//
//  MockServer+Environments.swift
//  CoderPadKit
//
//  Canned pad-environment fixtures: each id is a distinct environment so a
//  single pad can carry several languages and a mix of single- and multi-file
//  layouts. Split out of MockServer.swift to keep files within the limits.
//

import Foundation

nonisolated extension MockFixtures {
    static func padEnvironment(id: Int) -> [String: Any] {
        // Ids 2 and 4 are multi-file to exercise the per-file tabs and the "N files"
        // count; id 4 mixes HTML/CSS/JS so the per-file, extension-derived
        // highlighting is visible (each file rendered in its own language, not the
        // environment's).
        let environment = environmentFiles(id: id)
        return [
            "id": id,
            "pad_id": 88_112_233,
            "question_id": NSNull(),
            "example_question_id": NSNull(),
            "language": environment.language,
            "file_contents": environment.files,
            "created_at": "2026-06-09T18:00:00Z",
            "updated_at": "2026-06-09T18:00:00Z"
        ]
    }

    static func padHistory(environmentID: Int, fileIndex: Int) -> [String: Any]? {
        let files = environmentFiles(id: environmentID).files
        guard files.indices.contains(fileIndex), let contents = files[fileIndex]["contents"] as? String else {
            return nil
        }

        // One real-looking text file deliberately advertises a history URL that
        // returns 404, matching the partial-history responses clients must tolerate.
        guard !(environmentID == 34 && fileIndex == 1) else { return nil }

        let timestamp = historyStartTimestamp(environmentID: environmentID)
        if [41, 42].contains(environmentID) {
            return ["seed": ["a": "CoderPad", "o": [contents], "t": timestamp]]
        }

        let units = Array(contents.utf16)
        let split = units.count / 2
        let prefix = String(decoding: units[..<split], as: UTF16.self)
        let suffix = String(decoding: units[split...], as: UTF16.self)
        let seedAuthor = fileIndex == 0 ? "CoderPad" : "-MockUploadHistory01"

        return [
            "seed": ["a": seedAuthor, "o": [prefix], "t": timestamp],
            "candidate-edit": [
                "a": "4503601411610331", "o": [split, suffix], "t": timestamp + 1_204_000
            ],
            // Same-millisecond edits exercise deterministic id ordering. The
            // temporary trailing space is then deleted, leaving current contents.
            "interviewer-1-insert": [
                "a": "9988776655443322", "o": [units.count, " "], "t": timestamp + 2_515_000
            ],
            "interviewer-2-delete": [
                "a": "9988776655443322", "o": [units.count, -1], "t": timestamp + 2_515_000
            ]
        ]
    }

    /// Align each seeded pad's editor history with its event-log dates so run
    /// markers fall inside the playback track instead of days outside it.
    private static func historyStartTimestamp(environmentID: Int) -> Int64 {
        switch environmentID {
        case 21, 22: 1_780_680_600_000 // 2026-06-05T17:30:00Z
        case 31, 32, 34: 1_781_028_000_000 // 2026-06-09T18:00:00Z
        case 41, 42: 1_778_580_000_000 // 2026-05-12T10:00:00Z
        case 53: 1_780_995_600_000 // 2026-06-09T09:00:00Z
        default: 1_780_930_800_000 // 2026-06-08T15:00:00Z
        }
    }

    private static func file(
        environmentID: Int, index: Int, path: String, contents: String?, binary: Bool = false
    ) -> [String: Any] {
        [
            "path": path,
            "contents": contents as Any? ?? NSNull(),
            "binary": binary,
            // swiftlint:disable:next line_length
            "history": "https://coderpad-1.firebaseio.com/mock/pad-environments/\(environmentID)/files/\(index)/history.json"
        ]
    }

    private static func environmentFiles(id: Int) -> (language: String, files: [[String: Any]]) {
        switch id {
        case 1, 21, 31, 41:
            return ("python3", [
                file(environmentID: id, index: 0, path: "coderpad/main.py",
                     contents: "def greet(name):\n    return f\"Hello, {name}!\"\n\nprint(greet(\"CoderPad\"))\n")
            ])

        case 3, 53:
            let swift = "import Foundation\n\nfunc greet(_ name: String) -> String {\n"
                + "    \"Hello, \\(name)!\"\n}\n\nprint(greet(\"CoderPad\"))\n"
            return ("swift", [file(environmentID: id, index: 0, path: "main.swift", contents: swift)])

        case 4, 34:
            // A small mixed-language web project: each file is highlighted in its
            // own language (HTML, CSS, JavaScript) from its extension, even though
            // the environment reports a single language.
            return ("javascript", webProjectFiles(environmentID: id))

        default: // JavaScript environments (2, 22, 32, 42, and any other id)
            return ("javascript", [
                file(environmentID: id, index: 0, path: "src/index.js",
                     contents: "import { greet } from './greet.js';\n\nconsole.log(greet('CoderPad'));\n"),
                file(environmentID: id, index: 1, path: "src/greet.js",
                     contents: "export function greet(name) {\n  return `Hello, ${name}!`;\n}\n")
            ])
        }
    }

    private static func webProjectFiles(environmentID: Int) -> [[String: Any]] {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <title>Greeter</title>
            <link rel="stylesheet" href="styles.css" />
          </head>
          <body>
            <h1 id="greeting">Hello</h1>
            <script src="app.js"></script>
          </body>
        </html>

        """
        let css = """
        body {
          font-family: -apple-system, sans-serif;
          margin: 2rem;
        }

        #greeting {
          color: #2d6cdf;
          font-weight: 600;
        }

        """
        let javascript = """
        function greet(name) {
          return `Hello, ${name}!`;
        }

        document.getElementById('greeting').textContent = greet('CoderPad');

        """
        return [
            file(environmentID: environmentID, index: 0, path: "index.html", contents: html),
            file(environmentID: environmentID, index: 1, path: "styles.css", contents: css),
            file(environmentID: environmentID, index: 2, path: "app.js", contents: javascript),
            // Binary payloads arrive without text contents; the flag lets clients
            // distinguish them from empty text files.
            file(environmentID: environmentID, index: 3, path: "logo.png",
                 contents: nil, binary: true)
        ]
    }
}
