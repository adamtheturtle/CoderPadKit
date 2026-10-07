@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen question library")
struct ScreenQuestionBankTests {
    @Test
    func `list summaries preserve UUID identity and all response types`() async throws {
        let page = try await ScreenClient.mock().listQuestions()
        #expect(page.questions.count == 10)
        #expect(Set(page.questions.compactMap(\.type))
            == Set(["PROJECT", "CODE", "MCQ", "TEXT", "VIDEO", "GAME", "FILE_UPLOAD", "MULTI", "CLASH", "COURSE"]))
        #expect(page.questions.allSatisfy { $0.version == 1 })
        #expect(page.pagination?.total == 10)
        #expect(page.pagination?.hasMoreItems == false)
        for summary in page.questions {
            let detail = try await ScreenClient.mock().getQuestion(id: summary.id)
            #expect(detail.id == summary.id)
            #expect(detail.type == summary.type)
            #expect(detail.title == summary.title)
            #expect(detail.points == 0)
            #expect(detail.automaticallySelectable == false)
        }
    }

    @Test
    func `question details retain resources and server owned evaluation`() async throws {
        let id = try #require(UUID(uuidString: MockScreenFixtures.projectBankQuestionID))
        let result = try await ScreenClient.mock().getQuestion(id: id)
        #expect(result.projectDetails?.resources == [])
        #expect(result.projectDetails?.aiAssistAllowed == false)
        #expect(result.projectDetails?.downloadUrl == "https://example.com/project.tar.gz")
        #expect(result.projectDetails?.environment?.environmentID == "python")
        #expect(result.evaluation?.testReport?.testCases?.first?.key == "case-1")
        #expect(result.evaluation?.testReport?.testCases?.first?.points == 0)
    }

    @Test
    func `pagination preserves every filter and descending numeric order`() async throws {
        let filters = ScreenQuestionFilters(durationSecondsMin: 0, durationSecondsMax: 240,
                                             difficulty: .easy, domain: "Backend", skill: "Problem solving",
                                             programmingLanguage: "C++", fromCoderPadQuestionBank: false,
                                             product: .screen, sort: .durationSeconds, order: .desc)
        let result = try await ScreenClient.mock().listAllQuestions(filters: filters, limit: 1)
        #expect(result.map(\.durationSeconds) == [240, 180, 120, 60, 0])
        #expect(result.map(\.type) == ["VIDEO", "TEXT", "MCQ", "CODE", "PROJECT"])
        let empty = try await ScreenClient.mock().listAllQuestions(filters: ScreenQuestionFilters(type: "missing"))
        #expect(empty == [])
    }

    @Test(arguments: ScreenQuestionSave.QuestionType.allCases)
    func `create and update retain optional writable values and Location`(
        type: ScreenQuestionSave.QuestionType
    ) async throws {
        let client = ScreenClient.mock(key: "bank-write-\(UUID().uuidString)")
        let input = ScreenQuestionSave(type: type, durationSeconds: 0, points: 0,
                                       title: ["en": "Created", "fr": "Créée"], locales: [],
                                       automaticallySelectable: false)
        let created = try await client.createQuestion(input)
        #expect(created.question.type == type.rawValue)
        #expect(created.question.title == input.title)
        #expect(created.question.durationSeconds == 0)
        #expect(created.question.points == 0)
        #expect(created.question.locales == [])
        #expect(created.question.automaticallySelectable == false)
        #expect(created.question.version == 1)
        #expect(created.location == "/assessment/api/v1.1/questions/\(created.question.id.uuidString.lowercased())")
        var update = input
        update.title = ["en": "Updated"]
        let updated = try await client.updateQuestion(id: created.question.id, update)
        #expect(updated.title == ["en": "Updated"])
        #expect(updated.version == 2)
        #expect(try await client.getQuestion(id: created.question.id) == updated)
    }

    @Test
    func `save payload excludes unspecified values and preserves evaluation options`() throws {
        let input = ScreenQuestionSave(type: .mcq, title: ["en": "Pick one"],
            evaluation: ScreenEvaluationInput(choiceSelection: ScreenChoiceSelectionInput(correctChoiceIndexes: [])),
            mcqDetails: ScreenMCQInput(choices: [], selectionMode: .single, randomizeChoices: false))
        let expected = Data(#"""
        {"type":"MCQ","title":{"en":"Pick one"},"evaluation":{"choice_selection":{"correct_choice_indexes":[]}},
        "mcq_details":{"choices":[],"selection_mode":"SINGLE","randomize_choices":false}}
        """#.utf8)
        #expect(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(input))
            == JSONDecoder().decode(JSONValue.self, from: expected))
    }

    @Test
    func `project references are creation only and response download fields remain separate`() async throws {
        let client = ScreenClient.mock(key: "bank-project-\(UUID().uuidString)")
        let input = ScreenQuestionSave(type: .project, projectDetails: ScreenProjectInput(
            environment: ScreenEnvironmentInput(version: "1", environmentID: "python"), resources: [],
            aiAssistAllowed: false, temporaryFileID: UUID().uuidString
        ))
        let created = try await client.createQuestion(input)
        #expect(created.question.projectDetails?.environment?.environmentID == "python")
        #expect(created.question.projectDetails?.aiAssistAllowed == false)
        #expect(created.question.projectDetails?.resources == [])
        let error = await #expect(throws: CoderPadError.self) {
            try await client.updateQuestion(id: created.question.id, input)
        }
        guard case .http(400, _) = error else {
            Issue.record("Expected create-only archive error")
            return
        }
    }

    @Test
    func `permission missing and invalid page errors retain their public contract`() async throws {
        let client = ScreenClient.mock()
        let page = try await client.listQuestions(filters: ScreenQuestionFilters(type: "GAME"))
        let id = try #require(page.questions.first?.id)
        let error = await #expect(throws: CoderPadError.self) {
            try await client.updateQuestion(id: id, ScreenQuestionSave(type: .text))
        }
        guard case .http(403, _) = error else {
            Issue.record("Expected permission error")
            return
        }
        let missing = await #expect(throws: CoderPadError.self) { try await client.getQuestion(id: UUID()) }
        guard case .http(404, _) = missing else {
            Issue.record("Expected missing question error")
            return
        }
        await #expect(throws: CoderPadError.self) { try await client.listQuestions(start: -1) }
        await #expect(throws: CoderPadError.self) { try await client.listQuestions(limit: 0) }
    }
}
