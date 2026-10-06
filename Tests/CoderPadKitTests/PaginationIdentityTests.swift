@testable import CoderPadKit
import Foundation
import PaginatedRESTClient
import Testing

struct PaginationIdentityTests {
    @Test
    func `pad and question identities satisfy the generic pagination protocol`() throws {
        let pads = try JSONDecoder().decode(PadsPage.self, from: Data(
            #"{"pads":[{"id":"ABCD"}],"total":1,"next_page":null}"#.utf8
        ))
        let questions = try JSONDecoder().decode(QuestionsPage.self, from: Data(
            #"{"questions":[{"id":42}],"total":1,"next_page":null}"#.utf8
        ))
        #expect(identity(PadsPage.self, item: pads.pads[0]) == RESTItemIdentity("ABCD"))
        #expect(identity(QuestionsPage.self, item: questions.questions[0]) == RESTItemIdentity(42))
    }

    private func identity<Page: PagedResponse>(_: Page.Type, item: Page.Item) -> RESTItemIdentity? {
        Page.identity(of: item)
    }
}
