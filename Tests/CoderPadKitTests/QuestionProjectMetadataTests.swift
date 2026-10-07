@testable import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Parent-question project metadata")
struct QuestionProjectMetadataTests {
    @Test
    func `starter files and compact variants decode without full variant fields`() throws {
        let data = Data(#"""
        {"id":1,"file_contents":[{"path":"secret.txt","contents":"","hidden":true,"deleted":false},
        {"path":"obsolete.txt","deleted":true}],"question_variants":[
        {"id":2,"language":null,"project_template_id":7,"project_template_slug":"react","display":"React"},
        {"id":3,"language":"python3"}]}
        """#.utf8)
        let question = try JSONDecoder().decode(Question.self, from: data)
        #expect(question.fileContents?.map(\.path) == ["secret.txt", "obsolete.txt"])
        #expect(question.fileContents?.first?.contents == "")
        #expect(question.fileContents?.first?.hidden == true)
        #expect(question.fileContents?.first?.deleted == false)
        #expect(question.fileContents?.last?.contents == nil)
        #expect(question.fileContents?.last?.deleted == true)
        #expect(question.questionVariants?.map(\.id) == [2, 3])
        #expect(question.questionVariants?.first?.language == nil)
        #expect(question.questionVariants?.first?.projectTemplateID == 7)
        #expect(question.questionVariants?.first?.projectTemplateSlug == "react")
        #expect(question.questionVariants?.first?.display == "React")
        #expect(question.questionVariants?.last?.language == "python3")
        #expect(question.customFiles == [])
        #expect(try JSONDecoder().decode(Question.self, from: JSONEncoder().encode(question)) == question)
        let edited = question.applying(title: "Edited")
        #expect(edited.fileContents == question.fileContents)
        #expect(edited.questionVariants == question.questionVariants)
    }

    @Test(arguments: [#"{"id":1}"#, #"{"id":1,"file_contents":null,"question_variants":null}"#])
    func `missing and null metadata remain absent`(json: String) throws {
        let question = try JSONDecoder().decode(Question.self, from: Data(json.utf8))
        #expect(question.fileContents == nil)
        #expect(question.questionVariants == nil)
    }

    @Test
    func `explicit empty metadata remains empty`() throws {
        let question = try JSONDecoder().decode(Question.self,
                                                from: Data(#"{"id":1,"file_contents":[],"question_variants":[]}"#.utf8))
        #expect(question.fileContents == [])
        #expect(question.questionVariants == [])
    }

    @Test
    func `request encodes deletion without invented content and preserves hidden false`() throws {
        let input = QuestionCreate(title: "Project", fileContents: [
            QuestionFileContent(path: "old.txt", deleted: true),
            QuestionFileContent(path: "new.txt", contents: "", hidden: false, deleted: false)
        ])
        let expected = Data(#"""
        {"question":{"title":"Project","file_contents":[{"path":"old.txt","deleted":true},
        {"path":"new.txt","contents":"","hidden":false,"deleted":false}]}}
        """#.utf8)
        #expect(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(input))
            == JSONDecoder().decode(JSONValue.self, from: expected))
        let normalized = try #require(try validatedFileContents([
            QuestionFileContent(path: " src\\main.py ", contents: "print(1)", hidden: true)
        ]))
        #expect(normalized.first?.path == "src/main.py")
        #expect(normalized.first?.hidden == true)
    }

    @Test
    func `missing non-deletion contents and protected deletion are rejected`() {
        #expect(throws: QuestionMutationValidationError.missingFileContents("main.py")) {
            try JSONEncoder().encode(QuestionCreate(
                title: "Project", fileContents: [QuestionFileContent(path: "main.py")]
            ))
        }
        #expect(throws: QuestionMutationValidationError.protectedTemplateFile) {
            try JSONEncoder().encode(QuestionCreate(title: "Project",
                                                    fileContents: [QuestionFileContent(path: ".cpad", deleted: true)]))
        }
    }

    @Test(arguments: [nil, []] as [[QuestionFileContent]?])
    func `omitted and empty overlays retain demo template defaults`(files: [QuestionFileContent]?) async throws {
        let client = CoderPadClient.mock(key: "parent-default-\(UUID().uuidString)")
        let question = try await client.createQuestion(QuestionCreate(title: "React project", language: "react",
                                                                      fileContents: files))
        #expect(question.fileContents?.map(\.path) == [".cpad", "src/App.jsx"])
    }

    @Test
    func `creation overlays template files and parent update ignores deletion entries`() async throws {
        let client = CoderPadClient.mock(key: "parent-overlay-\(UUID().uuidString)")
        let question = try await client.createQuestion(QuestionCreate(title: "React project", language: "react",
                                                                      fileContents: [
            QuestionFileContent(path: "src/App.jsx", deleted: true),
            QuestionFileContent(path: "private.txt", contents: "answer", hidden: true)
        ]))
        #expect(question.fileContents?.map(\.path) == [".cpad", "private.txt"])
        #expect(question.fileContents?.last?.hidden == true)
        let updated = try await client.updateQuestion(QuestionUpdate(id: question.id, fileContents: [
            QuestionFileContent(path: "private.txt", deleted: true),
            QuestionFileContent(path: "new.txt", contents: "", hidden: false)
        ]))
        #expect(updated.fileContents?.map(\.path) == [".cpad", "private.txt", "new.txt"])
        #expect(updated.fileContents?.last?.contents == "")
        #expect(updated.fileContents?.last?.hidden == false)
    }

    @Test
    func `parent responses reflect compact variant metadata changes`() async throws {
        let client = CoderPadClient.mock(key: "parent-variants-\(UUID().uuidString)")
        let variant = try await client.createQuestionVariant(
            questionID: 101, QuestionVariantMutation(language: "react")
        )
        let question = try await client.getQuestion(id: 101)
        #expect(question.questionVariants?.map(\.id) == [variant.id])
        #expect(question.questionVariants?.first?.projectTemplateSlug == "react")
        try await client.deleteQuestionVariant(questionID: 101, id: variant.id)
        #expect(try await client.getQuestion(id: 101).questionVariants == [])
    }
}
