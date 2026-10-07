@testable import CoderPadKit
import Foundation
import Testing

nonisolated func decodedRequestArray(_ value: Any?) throws -> [[String: Any]] {
    let encoded = try #require(value as? String)
    return try #require(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [[String: Any]])
}

@Suite("Parent question array wire format")
struct QuestionArrayWireTests {
    @Test
    func `instruction JSON strings retain Unicode names false and empty lists`() throws {
        let step = CandidateInstructionPayload(instructions: "Read 世界 🌍", defaultVisible: false, name: "Part \"one\"")
        let encoded = try JSONEncoder().encode(QuestionCreate(title: "Question", candidateInstructions: [step]))
        let body = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let steps = try decodedRequestArray(body["candidate_instructions"])
        #expect(steps.count == 1)
        #expect(steps.first?["instructions"] as? String == "Read 世界 🌍")
        #expect(steps.first?["name"] as? String == "Part \"one\"")
        #expect(steps.first?["default_visible"] as? Bool == false)
        let empty = try JSONEncoder().encode(QuestionUpdate(id: 42, fileContents: [], candidateInstructions: []))
        let emptyBody = try #require(JSONSerialization.jsonObject(with: empty) as? [String: Any])
        #expect(emptyBody["candidate_instructions"] as? String == "[]")
        let question = try #require(emptyBody["question"] as? [String: Any])
        #expect(question["file_contents"] as? String == "[]")
    }

    @Test
    func `omitted arrays add no wire fields`() throws {
        let encoded = try JSONEncoder().encode(QuestionCreate(title: "Question"))
        let body = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let question = try #require(body["question"] as? [String: Any])
        #expect(body["candidate_instructions"] == nil)
        #expect(question["file_contents"] == nil)
    }
}
