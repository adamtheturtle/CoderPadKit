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

        // The live "Modify a question" contract carries the id only in the URL path.
        #expect(root["id"] == nil)
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

    @Test
    func `too many structured files are rejected before encoding`() {
        let fileContents = (0 ..< (QuestionFileContent.maximumFileCount + 1)).map {
            QuestionFileContent(path: "file\($0).py", contents: "x")
        }

        let error = #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionCreate(title: "Too many files", fileContents: fileContents))
        }
        #expect(
            error
                == .tooManyFileContents(
                    count: fileContents.count,
                    limit: QuestionFileContent.maximumFileCount
                )
        )
    }

    @Test
    func `a single oversized file is rejected before encoding`() {
        let oversized = String(repeating: "a", count: QuestionFileContent.maximumFileByteCount + 1)

        let error = #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionUpdate(
                id: 42,
                fileContents: [QuestionFileContent(path: "big.py", contents: oversized)]
            ))
        }
        #expect(
            error
                == .fileContentTooLarge(
                    path: "big.py",
                    byteCount: oversized.utf8.count,
                    limit: QuestionFileContent.maximumFileByteCount
                )
        )
    }

    @Test
    func `many small files exceeding the aggregate limit are rejected`() {
        // Individually well under the per-file limit, but their combined size busts
        // the aggregate ceiling.
        let chunkSize = QuestionFileContent.maximumFileByteCount / 2
        let fileCount = (QuestionFileContent.maximumAggregateByteCount / chunkSize) + 2
        let fileContents = (0 ..< fileCount).map {
            QuestionFileContent(path: "chunk\($0).py", contents: String(repeating: "a", count: chunkSize))
        }

        #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionCreate(title: "Aggregate limit", fileContents: fileContents))
        }
    }

    @Test
    func `file counts and sizes at the limit are accepted`() throws {
        _ = try CoderPadClient.encoder.encode(QuestionCreate(
            title: "At the limit",
            fileContents: [QuestionFileContent(
                path: "main.py",
                contents: String(repeating: "a", count: QuestionFileContent.maximumFileByteCount)
            )]
        ))
    }
}

@Suite("Question title validation")
struct QuestionTitleValidationTests {
    @Test(arguments: ["", "   ", "\u{0000}", "\t\n", "Bad\u{202E}title"])
    func `create rejects a blank or control-character title`(_ title: String) {
        #expect(throws: QuestionMutationValidationError.blankOrControlTitle) {
            _ = try CoderPadClient.encoder.encode(QuestionCreate(title: title))
        }
    }

    @Test(arguments: ["", "   ", "\u{0000}"])
    func `update rejects a blank or control-character title`(_ title: String) {
        #expect(throws: QuestionMutationValidationError.blankOrControlTitle) {
            _ = try CoderPadClient.encoder.encode(QuestionUpdate(id: 42, title: title))
        }
    }

    @Test
    func `create trims surrounding whitespace from a valid title`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionCreate(title: "  Two Sum  "))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])

        #expect(question["title"] as? String == "Two Sum")
    }

    @Test
    func `update with no title omits the nested title key`() throws {
        let data = try CoderPadClient.encoder.encode(
            QuestionUpdate(id: 42, language: "python3", description: "New description")
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let question = try #require(root["question"] as? [String: Any])

        #expect(question["title"] == nil)
        #expect(question["language"] as? String == "python3")
    }

    @Test
    func `update with none of title, language, or file contents omits the question object`() throws {
        let data = try CoderPadClient.encoder.encode(
            QuestionUpdate(id: 42, description: "New description")
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(root["question"] == nil)
    }
}

@Suite("Candidate instruction payload validation")
struct CandidateInstructionValidationTests {
    @Test(arguments: ["", "   ", "\u{0000}", "\u{202E}"])
    func `create rejects blank or control-character candidate instructions`(_ instructions: String) {
        #expect(throws: QuestionMutationValidationError.blankOrControlCandidateInstructions) {
            _ = try CoderPadClient.encoder.encode(QuestionCreate(
                title: "Q",
                candidateInstructions: [CandidateInstructionPayload(instructions: instructions, defaultVisible: true)]
            ))
        }
    }

    @Test
    func `create trims candidate instructions before encoding`() throws {
        let data = try CoderPadClient.encoder.encode(QuestionCreate(
            title: "Q",
            candidateInstructions: [
                CandidateInstructionPayload(instructions: "  Read the prompt carefully.  ", defaultVisible: false)
            ]
        ))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let instructions = try #require(root["candidate_instructions"] as? [[String: Any]])

        #expect(instructions[0]["instructions"] as? String == "Read the prompt carefully.")
        #expect(instructions[0]["default_visible"] as? Bool == false)
    }

    @Test
    func `an oversized candidate instructions block is rejected before encoding`() {
        let oversized = String(repeating: "a", count: CandidateInstructionPayload.maximumByteCount + 1)

        let error = #expect(throws: QuestionMutationValidationError.self) {
            try CoderPadClient.encoder.encode(QuestionCreate(
                title: "Q",
                candidateInstructions: [CandidateInstructionPayload(instructions: oversized, defaultVisible: true)]
            ))
        }
        #expect(
            error
                == .candidateInstructionsTooLarge(
                    byteCount: oversized.utf8.count,
                    limit: CandidateInstructionPayload.maximumByteCount
                )
        )
    }

    @Test
    func `candidate instructions at the size limit are accepted`() throws {
        let atLimit = String(repeating: "a", count: CandidateInstructionPayload.maximumByteCount)
        _ = try CoderPadClient.encoder.encode(QuestionCreate(
            title: "Q",
            candidateInstructions: [CandidateInstructionPayload(instructions: atLimit, defaultVisible: true)]
        ))
    }

    @Test
    func `an absent candidate instructions list is omitted rather than rejected`() throws {
        _ = try CoderPadClient.encoder.encode(QuestionCreate(title: "Q"))
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
