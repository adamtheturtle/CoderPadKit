import CoderPadKit
import Foundation
import Testing

@Suite("Binary starter-file response metadata")
struct QuestionBinaryMetadataTests {
    @Test(arguments: [nil, false, true] as [Bool?])
    func `binary marker retains all three states in both response models`(binary: Bool?) throws {
        var object: [String: Any] = ["path": "image.png", "hidden": true]
        object["binary"] = binary
        let data = try JSONSerialization.data(withJSONObject: object)
        let parent = try JSONDecoder().decode(QuestionStarterFile.self, from: data)
        let variant = try JSONDecoder().decode(QuestionVariantFileContent.self, from: data)
        #expect(parent.binary == binary)
        #expect(variant.binary == binary)
        #expect(parent.contents == nil)
        #expect(variant.contents == nil)
        #expect(try JSONDecoder().decode(QuestionStarterFile.self, from: JSONEncoder().encode(parent)) == parent)
        #expect(try JSONDecoder().decode(QuestionVariantFileContent.self,
                                        from: JSONEncoder().encode(variant)) == variant)
    }

    @Test
    func `mixed parent and variant responses retain binary and textual file states`() throws {
        let data = Data(#"""
        {"id":3,"question_id":42,"file_contents":[
        {"path":"image.png","binary":true,"hidden":true},
        {"path":"blank.txt","contents":"","binary":false},
        {"path":"text.txt","contents":"hello"},{"path":"old.txt","deleted":true}]}
        """#.utf8)
        let parent = try JSONDecoder().decode(Question.self, from: data)
        let variant = try JSONDecoder().decode(QuestionVariant.self, from: data)
        #expect(parent.fileContents?.map(\.binary) == [true, false, nil, nil])
        #expect(variant.fileContents?.map(\.binary) == [true, false, nil, nil])
        #expect(parent.fileContents?[1].contents == "")
        #expect(variant.fileContents?[3].deleted == true)
        #expect(try JSONDecoder().decode(Question.self, from: JSONEncoder().encode(parent)) == parent)
    }

    @Test
    func `mutation strips response metadata and refuses unavailable binary bodies`() throws {
        let text = QuestionVariantFileContent(path: "blank.txt", contents: "", binary: false)
        let mutation = QuestionVariantMutation(fileContents: [text])
        let data = try JSONEncoder().encode(mutation)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let files = try #require(body["file_contents"] as? [[String: Any]])
        #expect(files[0]["binary"] == nil)
        #expect(files[0]["contents"] as? String == "")
        #expect(throws: EncodingError.self) {
            try JSONEncoder().encode(QuestionVariantMutation(fileContents: [
                .init(path: "image.png", binary: true)
            ]))
        }
        let deletion = QuestionVariantMutation(fileContents: [.init(path: "image.png", deleted: true, binary: true)])
        let deletionData = try JSONEncoder().encode(deletion)
        #expect(!String(decoding: deletionData, as: UTF8.self).contains("binary"))
    }
}
