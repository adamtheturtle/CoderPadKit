@testable import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen duplicate invitation policy")
struct ScreenDuplicateInvitationTests {
    @Test(arguments: [nil, false, true] as [Bool?])
    func `serialization preserves all three policy states`(policy: Bool?) throws {
        let body = try JSONEncoder().encode(ScreenInvitation(allowDuplicateInvitations: policy))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Bool])
        let expected = policy.map { ["allow_duplicate_invitations": $0] } ?? [:]
        #expect(json == expected)
    }

    @Test
    func `duplicate rejection leaves the existing session intact`() async throws {
        let client = ScreenClient.mock(key: "duplicate-policy-\(UUID().uuidString)")
        let first = try await client.sendInvitation(
            campaignID: 101, ScreenInvitation(candidateEmail: "duplicate-policy@example.com")
        )
        do {
            _ = try await client.sendInvitation(
                campaignID: 101,
                ScreenInvitation(candidateEmail: "duplicate-policy@example.com", allowDuplicateInvitations: false)
            )
            Issue.record("Expected a duplicate invitation error")
        } catch let error as CoderPadError {
            #expect(error.description.contains("Candidate already invited"))
        }
        let repeated = try await client.sendInvitation(
            campaignID: 101,
            ScreenInvitation(candidateEmail: "duplicate-policy@example.com", allowDuplicateInvitations: true)
        )
        #expect(first.id != repeated.id)
        let tests = try await client.listTests(candidateEmail: "duplicate-policy@example.com")
        #expect(tests.pagination?.total == 2)
    }
}
