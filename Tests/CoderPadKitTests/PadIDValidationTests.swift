@testable import CoderPadKit
import Foundation
import Testing

@Suite("Pad ID path validation")
struct PadIDValidationTests {
    @Test(arguments: ["", ".", "..", "a/b", "a\\b", "a?admin=1", "a#fragment", "påd"])
    func `invalid path components are rejected`(id: String) throws {
        let error = #expect(throws: CoderPadError.self) {
            try CoderPadClient.validatePadID(id)
        }
        assertPadIDError(error)
    }

    @Test(arguments: ["DEMOABC1", "pad-123", "pad_123", "pad.name", "pad~name"])
    func `valid path components are accepted`(id: String) throws {
        try CoderPadClient.validatePadID(id)
    }

    @Test
    func `every pad endpoint validates its path ID before networking`() async {
        let id = "../questions"
        let client = CoderPadClient(apiKey: "key", session: URLSession(configuration: .ephemeral))

        await assertRejected { _ = try await client.getPad(id: id) }
        await assertRejected { _ = try await client.padEvents(padID: id) }
        await assertRejected { _ = try await client.updatePad(PadUpdate(id: id, title: "title")) }
        await assertRejected { try await client.updatePadWithoutRefetch(PadUpdate(id: id, title: "title")) }
        await assertRejected { try await client.endPad(id: id) }
        await assertRejected { try await client.deletePad(id: id) }
    }

    private func assertRejected(_ operation: () async throws -> Void) async {
        let error = await #expect(throws: CoderPadError.self) {
            try await operation()
        }
        assertPadIDError(error)
    }

    private func assertPadIDError(_ error: CoderPadError?) {
        guard case let .decode(detail) = error else {
            Issue.record("Expected a typed pad ID validation error")
            return
        }
        #expect(detail == "Pad ID must be one non-empty URL path component.")
    }
}
