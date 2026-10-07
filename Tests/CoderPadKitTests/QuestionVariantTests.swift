import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Question variants")
struct QuestionVariantTests {
    private let client = CoderPadClient.mock(key: "variants-\(UUID())")

    @Test
    func `variant lifecycle preserves omitted blank and default starter code`() async throws {
        #expect(try await client.listQuestionVariants(questionID: 101) == [])
        let variant = try await client.createQuestionVariant(questionID: 101,
                                                             .init(language: "ruby", contents: .value("puts 1")))
        #expect(variant.questionID == 101)
        #expect(variant.language == "ruby")
        #expect(try await client.getQuestionVariant(questionID: 101, id: variant.id) == variant)
        let preserved = try await client.updateQuestionVariant(questionID: 101, id: variant.id,
                                                               .init(solution: "puts 2"))
        #expect(preserved.contents == "puts 1")
        #expect(preserved.solution == "puts 2")
        let blank = try await client.updateQuestionVariant(questionID: 101, id: variant.id, .init(contents: .value("")))
        #expect(blank.contents == "")
        let reset = try await client.updateQuestionVariant(questionID: 101, id: variant.id,
                                                           .init(contents: .languageDefault))
        #expect(reset.contents == nil)
        #expect(try await client.listQuestionVariants(questionID: 101).map(\.id) == [variant.id])
        await #expect(throws: CoderPadError.self) {
            try await client.getQuestionVariant(questionID: 102, id: variant.id)
        }
        try await client.deleteQuestionVariant(questionID: 101, id: variant.id)
        #expect(try await client.listQuestionVariants(questionID: 101) == [])
    }

    @Test
    func `environment changes clear code unless replacement is provided`() async throws {
        let variant = try await client.createQuestionVariant(questionID: 101,
                                                             .init(language: "ruby", contents: .value("puts 1")))
        let cleared = try await client.updateQuestionVariant(
            questionID: 101, id: variant.id, .init(language: "python3")
        )
        #expect(cleared.contents == nil)
        let replaced = try await client.updateQuestionVariant(questionID: 101, id: variant.id,
                                                              .init(language: "ruby", contents: .value("puts 3")))
        #expect(replaced.contents == "puts 3")
    }

    @Test
    func `project files overlay on create replace on update and reset to the template`() async throws {
        let variant = try await client.createQuestionVariant(questionID: 101, .init(language: "react", fileContents: [
            .init(path: "src/App.jsx", deleted: true), .init(path: "hello world.jsx", contents: "hello", hidden: true)
        ]))
        #expect(variant.projectTemplateSlug == "react")
        #expect(variant.language == nil)
        #expect(variant.fileContents?.map(\.path) == [".cpad", "hello world.jsx"])
        #expect(variant.fileContents?.last?.hidden == true)
        let replaced = try await client.updateQuestionVariant(questionID: 101, id: variant.id, .init(fileContents: [
            .init(path: ".cpad", contents: "{}"), .init(path: "new.jsx", contents: "new")
        ]))
        #expect(replaced.fileContents?.map(\.path) == [".cpad", "new.jsx"])
        let reset = try await client.updateQuestionVariant(questionID: 101, id: variant.id, .init(fileContents: []))
        #expect(reset.fileContents?.map(\.path) == [".cpad", "src/App.jsx"])
        await #expect(throws: CoderPadError.self) {
            try await client.updateQuestionVariant(questionID: 101, id: variant.id,
                                                   .init(fileContents: [.init(path: ".cpad", deleted: true)]))
        }
    }

    @Test
    func `encoding preserves the three starter code states and rejects conflicting sources`() throws {
        let encoder = JSONEncoder()
        #expect(try String(decoding: encoder.encode(QuestionVariantMutation()), as: UTF8.self) == "{}")
        #expect(try String(decoding: encoder.encode(QuestionVariantMutation(contents: .value(""))),
                           as: UTF8.self) == #"{"contents":""}"#)
        #expect(try String(decoding: encoder.encode(QuestionVariantMutation(contents: .languageDefault)),
                           as: UTF8.self) == #"{"contents":null}"#)
        #expect(throws: QuestionMutationValidationError.mutuallyExclusiveContentSources) {
            try encoder.encode(QuestionVariantMutation(contents: .languageDefault, fileContents: []))
        }
    }

    @Test
    func `file contents can also be sent as a JSON string`() async throws {
        let json = #"[{"path":"src/App.jsx","deleted":true},{"path":"new.jsx","contents":"hi"}]"#
        let variant = try await client.createQuestionVariant(questionID: 101,
                                                             .init(language: "react", fileContentsJSON: json))
        #expect(variant.fileContents?.map(\.path) == [".cpad", "new.jsx"])
        #expect(throws: QuestionMutationValidationError.mutuallyExclusiveContentSources) {
            try JSONEncoder().encode(QuestionVariantMutation(fileContents: [], fileContentsJSON: "[]"))
        }
    }

    @Test
    func `invalid IDs and missing create language fail before networking`() async {
        await #expect(throws: CoderPadError.self) { try await client.listQuestionVariants(questionID: 0) }
        await #expect(throws: CoderPadError.self) { try await client.getQuestionVariant(questionID: 101, id: -1) }
        await #expect(throws: EncodingError.self) { try await client.createQuestionVariant(questionID: 101, .init()) }
    }
}
