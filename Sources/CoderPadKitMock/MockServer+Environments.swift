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

        return [
            "initial": ["a": "candidate@example.com", "o": [contents], "t": Int64(1_700_000_000_000)]
        ]
    }

    private static func file(
        environmentID: Int, index: Int, path: String, contents: String?, binary: Bool = false
    ) -> [String: Any] {
        [
            "path": path,
            "contents": contents as Any? ?? NSNull(),
            "binary": binary,
            "history": "https://coderpad-1.firebaseio.com/mock/pad-environments/\(environmentID)/files/\(index)/history.json"
        ]
    }

    private static func environmentFiles(id: Int) -> (language: String, files: [[String: Any]]) {
        switch id {
        case 1:
            return ("python3", [
                file(environmentID: id, index: 0, path: "coderpad/main.py",
                     contents: "def greet(name):\n    return f\"Hello, {name}!\"\n\nprint(greet(\"CoderPad\"))\n")
            ])

        case 3:
            let swift = "import Foundation\n\nfunc greet(_ name: String) -> String {\n"
                + "    \"Hello, \\(name)!\"\n}\n\nprint(greet(\"CoderPad\"))\n"
            return ("swift", [file(environmentID: id, index: 0, path: "main.swift", contents: swift)])

        case 4:
            // A small mixed-language web project: each file is highlighted in its
            // own language (HTML, CSS, JavaScript) from its extension, even though
            // the environment reports a single language.
            return ("javascript", webProjectFiles(environmentID: id))

        default: // 2 and any other id
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
