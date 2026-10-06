import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Candidate instruction step names")
struct InstructionStepNameTests {
    @Test(arguments: [nil, "", "Part one"] as [String?])
    func `create and update preserve optional names`(name: String?) async throws {
        let client = CoderPadClient.mock(key: "step-name-\(UUID().uuidString)")
        let step = CandidateInstructionPayload(instructions: "Do the thing", defaultVisible: true, name: name)
        let created = try await client.createQuestion(QuestionCreate(
            title: "Named steps", language: "python3", candidateInstructions: [step]
        ))
        #expect(created.candidateInstructions.map(\.name) == [name])
        let updated = try await client.updateQuestion(QuestionUpdate(
            id: created.id,
            candidateInstructions: [
                step, CandidateInstructionPayload(instructions: "Continue", defaultVisible: false, name: "Part two")
            ]
        ))
        #expect(updated.candidateInstructions.map(\.name) == [name, "Part two"])
        #expect(updated.candidateInstructions.map(\.defaultVisible) == [true, false])
    }

    @Test
    func `omitted names are absent from encoded instruction payloads`() throws {
        let step = CandidateInstructionPayload(instructions: "Do the thing", defaultVisible: true)
        let body = try JSONEncoder().encode(step)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json.keys.sorted() == ["default_visible", "instructions"])
    }
}
