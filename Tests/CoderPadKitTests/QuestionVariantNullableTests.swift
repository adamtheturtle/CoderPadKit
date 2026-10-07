import CoderPadKit
import Foundation
import Testing

@Suite("Nullable project variant fields")
struct QuestionVariantNullableTests {
    @Test
    func `full project variants decode null language and path-only removed files`() throws {
        let data = Data(#"""
        {"id":3,"question_id":42,"language":null,"project_template_id":7,
         "project_template_slug":"react","contents":null,"solution":null,
         "file_contents":[{"path":"src/App.jsx","deleted":true},
                          {"path":"secret.txt","contents":"","hidden":false}]}
        """#.utf8)
        let variant = try JSONDecoder().decode(QuestionVariant.self, from: data)
        #expect(variant.language == nil)
        #expect(variant.projectTemplateSlug == "react")
        #expect(variant.fileContents?.first?.contents == nil)
        #expect(variant.fileContents?.first?.deleted == true)
        #expect(variant.fileContents?.last?.contents == "")
        #expect(variant.fileContents?.last?.hidden == false)
        #expect(try JSONDecoder().decode(QuestionVariant.self, from: JSONEncoder().encode(variant)) == variant)
    }

    @Test
    func `path-only removal mutations omit contents instead of inserting blank text`() throws {
        let mutation = QuestionVariantMutation(fileContents: [.init(path: "src/App.jsx", deleted: true)])
        let data = try JSONEncoder().encode(mutation)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let files = try #require(object["file_contents"] as? [[String: Any]])
        #expect(files.first?.keys.sorted() == ["deleted", "path"])
        #expect(files.first?["deleted"] as? Bool == true)
    }
}
