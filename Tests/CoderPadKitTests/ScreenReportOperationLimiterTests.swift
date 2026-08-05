//
//  ScreenReportOperationLimiterTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen report operation limiter")
struct ScreenReportOperationLimiterTests {
    @Test
    func `configured queue capacity is enforced with a typed error`() async throws {
        let limiter = ScreenReportOperationLimiter(
            maximumConcurrentOperations: 1,
            maximumQueuedOperations: 1
        )
        try await limiter.acquire(id: UUID())
        let waiter = Task { try await limiter.acquire(id: UUID()) }
        try await waitForQueueSize(1, on: limiter)

        let error = await #expect(throws: ScreenReportOperationLimiterError.self) {
            try await limiter.acquire(id: UUID())
        }
        #expect(error == .queueFull(limit: 1))

        await limiter.release()
        try await waiter.value
        await limiter.release()
        #expect(await limiter.activeOperationCount == 0)
    }

    @Test
    func `cancel racing release returns a transferred slot`() async throws {
        let limiter = ScreenReportOperationLimiter(
            maximumConcurrentOperations: 1,
            maximumQueuedOperations: 1
        )
        try await limiter.acquire(id: UUID())
        let waiterID = UUID()
        let waiter = Task { try await limiter.acquire(id: waiterID) }
        try await waitForQueueSize(1, on: limiter)

        waiter.cancel()
        await limiter.release()

        await #expect(throws: CancellationError.self) {
            try await waiter.value
        }
        #expect(await limiter.activeOperationCount == 0)
        #expect(await limiter.queuedOperationCount == 0)
    }

    private func waitForQueueSize(
        _ expected: Int,
        on limiter: ScreenReportOperationLimiter
    ) async throws {
        for _ in 0 ..< 100 {
            if await limiter.queuedOperationCount == expected { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Limiter queue did not reach \(expected) waiter(s).")
    }
}
