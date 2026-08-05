import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Organization statistics range validation")
struct OrganizationStatsRangeTests {
    private let client = CoderPadClient.mock(key: "stats-range-\(UUID().uuidString)")
    private let start = Date(timeIntervalSince1970: 1_767_225_600)
    private let end = Date(timeIntervalSince1970: 1_767_312_000)

    @Test
    func `nil equal and ordered ranges are accepted`() async throws {
        let defaultRange = try await client.organizationStats()
        let equalRange = try await client.organizationStats(start: start, end: start)
        let orderedRange = try await client.organizationStats(start: start, end: end)

        #expect(defaultRange.startTime != nil)
        #expect(defaultRange.endTime != nil)
        #expect(equalRange.startTime == start)
        #expect(equalRange.endTime == start)
        #expect(orderedRange.startTime == start)
        #expect(orderedRange.endTime == end)
    }

    @Test(arguments: [true, false])
    func `one-sided ranges fail locally`(startOnly: Bool) async {
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.organizationStats(
                start: startOnly ? start : nil,
                end: startOnly ? nil : end
            )
        }

        guard case let .decode(detail) = error else {
            Issue.record("Expected a typed decode error")
            return
        }
        #expect(detail == "Organization statistics start and end must be supplied together.")
    }

    @Test
    func `reversed ranges fail locally`() async {
        let error = await #expect(throws: CoderPadError.self) {
            _ = try await client.organizationStats(start: end, end: start)
        }

        guard case let .decode(detail) = error else {
            Issue.record("Expected a typed decode error")
            return
        }
        #expect(detail == "Organization statistics start must not be later than its end.")
    }
}
