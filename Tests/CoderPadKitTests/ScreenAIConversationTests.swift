@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen AI Assist conversations")
struct ScreenAIConversationTests {
    private let questionID = UUID(uuidString: MockScreenFixtures.aiProjectQuestionID)!

    @Test
    func `conversations preserve ordered messages and original output fields`() async throws {
        let result = try await ScreenClient.mock().aiAssistConversations(testID: 5001, questionID: questionID)
        #expect(result.map(\.id) == ["conversation-1", "conversation-2"])
        #expect(result.first?.subject == "Project guidance")
        #expect(result.first?.creationTime == "2026-10-01T12:00:00.123Z")
        #expect(result.first?.messages.map(\.id) == ["message-1", "message-2"])
        #expect(result.first?.messages.map(\.role) == [.user, .assistant])
        #expect(result.first?.messages.first?.creationTime == "2026-10-01T12:00:00.123Z")
        #expect(result.first?.messages.first?.outputItems == [
            .object(["type": .string("text"), "text": .string("Can you explain this test?"),
                     "future": .object(["flag": .bool(false)])])
        ])
        #expect(result.first?.messages.last?.outputItems == [
            .object(["type": .string("reasoning"),
                     "details": .object(["steps": .array([.string("inspect"), .string("explain")])])]),
            .object(["type": .string("tool_call"), "tool": .string("read_file"),
                     "metadata": .object(["path": .string("test.py"), "attempt": .number(0)])]),
            .object(["type": .string("text"), "text": .string("The test checks the returned value.")])
        ])
        #expect(result.last?.messages == [])
        #expect(result.last?.subject == nil)
        #expect(result.last?.creationTime == nil)
    }

    @Test
    func `empty conversations and manual review are supported`() async throws {
        #expect(try await ScreenClient.mock().aiAssistConversations(testID: 5002, questionID: questionID) == [])
        let key = "ai-review-\(UUID().uuidString)"
        defer { ScreenClient.resetMockState(forKey: key) }
        let state = MockScreenStateRegistry.state(forKey: key)
        state.lock.withLock { _ in
            state.createdTests.append(["id": 5901, "status": "in_progress", "approval_status": "TO_REVIEW"])
        }
        #expect(try await ScreenClient.mock(key: key).aiAssistConversations(testID: 5901, questionID: questionID) == [])
    }

    @Test(arguments: [nil, "null", "[]"] as [String?])
    func `absent null and empty message output remain distinct`(output: String?) throws {
        let field = output.map { ",\"output_items\":\($0)" } ?? ""
        let data = Data("{\"id\":\"message\",\"role\":\"USER\"\(field)}".utf8)
        let message = try JSONDecoder().decode(ScreenAIMessage.self, from: data)
        #expect(message.outputItems == (output == "[]" ? [] : nil))
        #expect(message.creationTime == nil)
        let conversation = try JSONDecoder().decode(ScreenAIConversation.self,
                                                    from: Data(#"{"id":"empty"}"#.utf8))
        #expect(conversation.messages == [])
    }

    @Test(arguments: [404, 409])
    func `missing questions and unfinished tests retain HTTP errors`(status: Int) async throws {
        do {
            _ = try await ScreenClient.mock().aiAssistConversations(testID: status == 409 ? 5003 : 5001,
                                                                   questionID: status == 404 ? UUID() : questionID)
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case let .http(code, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == status)
        }
    }

    @Test
    func `invalid test IDs and unauthorized requests use existing errors`() async throws {
        await #expect(throws: CoderPadError.self) {
            try await ScreenClient.mock().aiAssistConversations(testID: 0, questionID: questionID)
        }
        do {
            _ = try await ScreenClient.mock(unauthorized: true).aiAssistConversations(testID: 5001,
                                                                                     questionID: questionID)
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case .http(401, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }
}
