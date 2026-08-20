//
//  ModelTests.swift
//  CoderPadKitTests
//
//  Pure value-type behavior: state/type normalization, the execution_enabled string
//  quirk, and decode tolerance. No network.
//

import CoderPadKit
import Foundation
import Testing

@Suite("PadState normalization")
struct PadStateTests {
    @Test
    func `known synonyms fold into typed cases`() {
        #expect(PadState(apiState: "started") == .active)
        #expect(PadState(apiState: "running") == .active)
        #expect(PadState(apiState: "finished") == .ended)
        #expect(PadState(apiState: "draft") == .pending)
        #expect(PadState(apiState: "deleted") == .deleted)
    }

    @Test
    func `unrecognized states are preserved verbatim as other`() {
        #expect(PadState(apiState: "archived") == .other("archived"))
        #expect(PadState(apiState: "archived").rawValue == "archived")
    }

    @Test
    func `live is an interview type not a lifecycle state`() {
        // "live" belongs to InterviewType (format), not PadState (lifecycle), so it
        // must not fold into .active; it falls through like any unrecognized state.
        #expect(PadState(apiState: "live") == .other("live"))
    }

    @Test
    func `rawValue round-trips through RawRepresentable`() {
        for state in [PadState.active, .ended, .pending, .deleted, .other("custom")] {
            #expect(PadState(rawValue: state.rawValue) == state)
        }
    }

    @Test
    func `only ended is terminal`() {
        #expect(PadState.ended.isEnded)
        #expect(!PadState.active.isEnded)
    }
}

@Suite("InterviewType normalization")
struct InterviewTypeTests {
    @Test
    func `accepts the hyphen and underscore spellings`() {
        #expect(InterviewType(rawType: "live") == .live)
        #expect(InterviewType(rawType: "take-home") == .takeHome)
        #expect(InterviewType(rawType: "take_home") == .takeHome)
        #expect(InterviewType(rawType: "takehome") == .takeHome)
    }

    @Test
    func `nil for empty or unrecognized values`() {
        #expect(InterviewType(rawType: nil) == nil)
        #expect(InterviewType(rawType: "") == nil)
        #expect(InterviewType(rawType: "phone") == nil)
    }
}

@Suite("execution_enabled string quirk")
struct ExecutionEnabledTests {
    @Test
    func `PadCreate encodes execution_enabled as a JSON string, not a boolean`() throws {
        let data = try CoderPadClient.encoder.encode(PadCreate(executionEnabled: true))
        let json = String(decoding: data, as: UTF8.self)
        // The documented boolean is silently ignored by the live API; the string form
        // is what actually takes effect (see PadCreate's discussion).
        #expect(json.contains("\"execution_enabled\":\"true\""))
        #expect(!json.contains("\"execution_enabled\":true"))
    }

    @Test
    func `PadCreate decodes either the string form or a plain boolean`() throws {
        let fromString = try CoderPadClient.decoder.decode(
            PadCreate.self, from: Data(#"{"execution_enabled":"true"}"#.utf8)
        )
        #expect(fromString.executionEnabled == true)

        let fromBool = try CoderPadClient.decoder.decode(
            PadCreate.self, from: Data(#"{"execution_enabled":false}"#.utf8)
        )
        #expect(fromBool.executionEnabled == false)
    }

    @Test(arguments: ["TRUE", "False", "yes", "1", " true "])
    func `strict request models reject unknown execution strings`(_ value: String) {
        let data = Data(#"{"execution_enabled":"\#(value)"}"#.utf8)

        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(PadCreate.self, from: data)
        }
    }

    @Test(arguments: ["TRUE", "False", "yes", "1", " true "])
    func `lenient response models preserve unknown execution strings as nil`(_ value: String) throws {
        let data = Data(#"{"id":"X1","execution_enabled":"\#(value)"}"#.utf8)

        let pad = try CoderPadClient.decoder.decode(Pad.self, from: data)

        #expect(pad.executionEnabled == nil)
    }

    @Test
    func `a nil execution flag is omitted entirely`() throws {
        let data = try CoderPadClient.encoder.encode(PadCreate(title: "No flag"))
        #expect(!String(decoding: data, as: UTF8.self).contains("execution_enabled"))
    }

    /// The package writes `execution_enabled` as a JSON string, so the response model
    /// has to read that shape back. A strict `Bool` decode silently produced `nil`,
    /// making the flag the package had just set read as "unknown".
    @Test
    func `Pad decodes execution_enabled in the string form the package sends`() throws {
        let fromString = try CoderPadClient.decoder.decode(
            Pad.self, from: Data(#"{"id":"X1","execution_enabled":"true"}"#.utf8)
        )
        #expect(fromString.executionEnabled == true)

        let fromFalseString = try CoderPadClient.decoder.decode(
            Pad.self, from: Data(#"{"id":"X1","execution_enabled":"false"}"#.utf8)
        )
        #expect(fromFalseString.executionEnabled == false)

        // The published-docs boolean shape keeps working.
        let fromBool = try CoderPadClient.decoder.decode(
            Pad.self, from: Data(#"{"id":"X1","execution_enabled":true}"#.utf8)
        )
        #expect(fromBool.executionEnabled == true)

        // An absent flag is still "unknown", not a fabricated false.
        let absent = try CoderPadClient.decoder.decode(Pad.self, from: Data(#"{"id":"X1"}"#.utf8))
        #expect(absent.executionEnabled == nil)
    }
}

@Suite("Question mutation file contents")
struct QuestionFileContentTests {
    @Test
    func `create encodes multiple files under the question parameter`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionCreate(
            title: "Multi-file",
            language: "multifile_python",
            fileContents: [
                QuestionFileContent(path: "main.py", contents: "print('Hello, 世界 🌍')"),
                QuestionFileContent(path: "lib/empty.py", contents: "")
            ]
        ))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])
        let files = try #require(question["file_contents"] as? [[String: Any]])

        #expect(files.count == 2)
        #expect(files[0]["path"] as? String == "main.py")
        #expect(files[0]["contents"] as? String == "print('Hello, 世界 🌍')")
        #expect(files[1]["path"] as? String == "lib/empty.py")
        #expect(files[1]["contents"] as? String == "")
        #expect(root["contents"] == nil)
    }

    @Test
    func `update encodes a structured file replacement without title or language`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionUpdate(
            id: 42,
            fileContents: [QuestionFileContent(path: "Sources/main.swift", contents: "print(«hej»)")]
        ))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])
        let files = try #require(question["file_contents"] as? [[String: Any]])

        #expect(root["id"] as? Int == 42)
        #expect(files.count == 1)
        #expect(files[0]["path"] as? String == "Sources/main.swift")
        #expect(files[0]["contents"] as? String == "print(«hej»)")
    }

    @Test
    func `an explicitly empty file list is encoded`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionUpdate(id: 42, fileContents: []))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])
        let files = try #require(question["file_contents"] as? [Any])

        #expect(files.isEmpty)
    }

    @Test
    func `legacy single-file contents remain flat and source-compatible`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionCreate(
            title: "Single-file",
            contents: "print('unchanged')"
        ))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])

        #expect(root["contents"] as? String == "print('unchanged')")
        #expect(question["file_contents"] == nil)
    }

    @Test
    func `create rejects single-file and structured contents together`() {
        #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionCreate(
                title: "Conflict",
                contents: "legacy",
                fileContents: [QuestionFileContent(path: "main.py", contents: "structured")]
            ))
        }
    }

    @Test
    func `update rejects single-file and even an empty structured list together`() {
        #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionUpdate(
                id: 42,
                contents: "legacy",
                fileContents: []
            ))
        }
    }
}

@Suite("CoderPadError")
struct CoderPadErrorTests {
    @Test
    func `401 and 403 are unauthorized; others are not`() {
        #expect(CoderPadError.http(401, "").isUnauthorized)
        #expect(CoderPadError.http(403, "").isUnauthorized)
        #expect(!CoderPadError.http(404, "").isUnauthorized)
        #expect(!CoderPadError.missingAPIKey.isUnauthorized)
    }
}
