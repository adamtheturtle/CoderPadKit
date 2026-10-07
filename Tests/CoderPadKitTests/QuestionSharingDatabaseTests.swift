import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Question sharing and database selection")
struct QuestionSharingDatabaseTests {
    @Test(arguments: [nil, false, true] as [Bool?], [nil, 501] as [Int?])
    func `create encodes optional sharing and integer database identity`(shared: Bool?, databaseID: Int?) throws {
        let body = QuestionCreate(title: "Database question", shared: shared, customDatabaseID: databaseID)
        let data = try CoderPadClient.makeEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var expected: [String: Any] = ["question": ["title": "Database question"]]
        if let shared { expected["shared"] = shared }
        if let databaseID { expected["custom_database_id"] = databaseID }
        #expect(NSDictionary(dictionary: object) == NSDictionary(dictionary: expected))
    }

    @Test(arguments: [nil, false, true] as [Bool?], [nil, 501] as [Int?])
    func `updates omit identity and retain explicit false`(shared: Bool?, databaseID: Int?) throws {
        let body = QuestionUpdate(id: 101, shared: shared, customDatabaseID: databaseID)
        let data = try CoderPadClient.makeEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var expected: [String: Any] = [:]
        if let shared { expected["shared"] = shared }
        if let databaseID { expected["custom_database_id"] = databaseID }
        #expect(NSDictionary(dictionary: object) == NSDictionary(dictionary: expected))
    }

    @Test
    func `mock create and updates retain selections while omitted fields stay unchanged`() async throws {
        let client = CoderPadClient.mock(key: "question-sharing-\(UUID().uuidString)")
        let created = try await client.createQuestion(QuestionCreate(
            title: "Database question", language: "postgresql", shared: false, customDatabaseID: 501
        ))
        #expect(created.shared == false)
        #expect(created.customDatabase?.id == 501)
        let renamed = try await client.updateQuestion(QuestionUpdate(id: created.id, title: "Renamed"))
        #expect(renamed.shared == false)
        #expect(renamed.customDatabase?.id == 501)
        let shared = try await client.updateQuestion(QuestionUpdate(id: created.id, shared: true))
        #expect(shared.shared == true)
        #expect(shared.customDatabase?.id == 501)
        let linked = try await client.updateQuestion(QuestionUpdate(id: created.id, customDatabaseID: 501))
        #expect(linked.shared == true)
        #expect(linked.customDatabase?.id == 501)
    }

    @Test
    func `mock multipart creation and updates preserve Boolean and database fields`() async throws {
        let client = CoderPadClient.mock(key: "question-sharing-zip-\(UUID().uuidString)")
        let archive = QuestionZIPUpload(data: Data([0x50, 0x4B, 0x03, 0x04]), filename: "question.zip")
        let created = try await client.createQuestion(
            QuestionCreate(title: "Files", shared: false, customDatabaseID: 501), zipFile: archive
        )
        #expect(created.shared == false)
        #expect(created.customDatabase?.id == 501)
        let updated = try await client.updateQuestion(
            QuestionUpdate(id: created.id, shared: true, customDatabaseID: 501), zipFile: archive
        )
        #expect(updated.shared == true)
        #expect(updated.customDatabase?.id == 501)
    }

    @Test
    func `sharing another authors question surfaces permission failure without mutation`() async throws {
        let client = CoderPadClient.mock(key: "question-sharing-author-\(UUID().uuidString)")
        let before = try await client.getQuestion(id: 101)
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.updateQuestion(QuestionUpdate(id: before.id, shared: false))
        }
        #expect(error?.isUnauthorized == true)
        #expect(try await client.getQuestion(id: before.id).shared == before.shared)
    }

    @Test
    func `unknown database identities surface API failures before mock state changes`() async throws {
        let client = CoderPadClient.mock(key: "question-sharing-invalid-db-\(UUID().uuidString)")
        let before = try await client.listQuestions()
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.createQuestion(QuestionCreate(title: "Invalid", customDatabaseID: 999))
        }
        if case .http(400, _) = error {} else { Issue.record("Expected HTTP 400 for an unknown custom database") }
        #expect(try await client.listQuestions().map(\.id) == before.map(\.id))
        let updateError = await #expect(throws: CoderPadError.self) {
            _ = try await client.updateQuestion(QuestionUpdate(id: 101, customDatabaseID: 999))
        }
        if case .http(400, _) = updateError {} else { Issue.record("Expected HTTP 400 for an unknown custom database") }
    }
}
