@testable import CoderPadKit
import Foundation
import Testing

@Suite("Pad event identity")
struct PadEventIdentityTests {
    @Test
    func `distinct events with matching timestamp kind actor and message remain unequal only by content`() {
        let first = PadEvent(
            message: "joined",
            kind: "joined",
            metadata: "spectator",
            userName: "Ada",
            userEmail: "ada@example.com",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let second = PadEvent(
            message: "joined",
            kind: "joined",
            metadata: "participant",
            userName: "Ada",
            userEmail: "other@example.com",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(first != second)
    }
}
