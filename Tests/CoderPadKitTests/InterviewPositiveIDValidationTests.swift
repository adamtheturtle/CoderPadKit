@testable import CoderPadKit
import Foundation
import Testing

@Suite("Interview positive resource IDs")
struct InterviewPositiveIDValidationTests {
    @Test(arguments: [-1, 0, Int.min])
    func `nonpositive resource IDs are rejected`(id: Int) {
        let error = #expect(throws: CoderPadError.self) {
            try CoderPadClient.validatePositiveResourceID(id, kind: "question")
        }
        assertPositiveIDError(error, kind: "question")
    }

    @Test(arguments: [1, 42, Int.max])
    func `positive resource IDs are accepted`(id: Int) throws {
        try CoderPadClient.validatePositiveResourceID(id, kind: "question")
    }

    @Test(arguments: [-7, 0])
    func `question and pad-environment endpoints reject nonpositive IDs before networking`(id: Int) async {
        let client = CoderPadClient(apiKey: "key", session: URLSession(configuration: .ephemeral))
        let zip = QuestionZIPUpload(data: Data([0x50, 0x4B, 0x03, 0x04]), filename: "q.zip")

        await assertRejected(kind: "question") { _ = try await client.getQuestion(id: id) }
        await assertRejected(kind: "question") {
            _ = try await client.updateQuestion(QuestionUpdate(id: id, title: "t"))
        }
        await assertRejected(kind: "question") {
            try await client.updateQuestionWithoutRefetch(QuestionUpdate(id: id, title: "t"))
        }
        await assertRejected(kind: "question") {
            _ = try await client.updateQuestion(QuestionUpdate(id: id, title: "t"), zipFile: zip)
        }
        await assertRejected(kind: "question") {
            try await client.updateQuestionWithoutRefetch(QuestionUpdate(id: id, title: "t"), zipFile: zip)
        }
        await assertRejected(kind: "question") { try await client.deleteQuestion(id: id) }
        await assertRejected(kind: "pad environment") { _ = try await client.padEnvironment(id: id) }
    }

    private func assertRejected(kind: String, _ operation: () async throws -> Void) async {
        let error = await #expect(throws: CoderPadError.self) {
            try await operation()
        }
        assertPositiveIDError(error, kind: kind)
    }

    private func assertPositiveIDError(_ error: CoderPadError?, kind: String) {
        guard case let .decode(detail) = error else {
            Issue.record("Expected a typed Interview ID validation error")
            return
        }
        #expect(detail == "Interview \(kind) ID must be positive.")
    }
}
