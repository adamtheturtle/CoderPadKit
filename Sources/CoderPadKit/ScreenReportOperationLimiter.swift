//
//  ScreenReportOperationLimiter.swift
//  coderpad
//

import Foundation

/// Admission failure from the process-wide Screen report operation gate.
public nonisolated enum ScreenReportOperationLimiterError: Error, Equatable, Sendable {
    /// Every execution slot and every bounded queue position is occupied.
    case queueFull(limit: Int)
}

/// A process-wide gate for sensitive, potentially large Screen report downloads.
/// It is shared by every `ScreenClient`, so opening reports in several windows or
/// accounts cannot create an unbounded collection of in-flight temporary files.
actor ScreenReportOperationLimiter {
    public static let shared = ScreenReportOperationLimiter(
        maximumConcurrentOperations: 2,
        maximumQueuedOperations: 8
    )

    private let maximumConcurrentOperations: Int
    private let maximumQueuedOperations: Int
    private var activeOperations = 0
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    init(maximumConcurrentOperations: Int, maximumQueuedOperations: Int = 8) {
        precondition(maximumConcurrentOperations > 0)
        precondition(maximumQueuedOperations >= 0)
        self.maximumConcurrentOperations = maximumConcurrentOperations
        self.maximumQueuedOperations = maximumQueuedOperations
    }

    public func acquire(id: UUID) async throws {
        try Task.checkCancellation()
        if activeOperations < maximumConcurrentOperations {
            activeOperations += 1
            return
        }

        guard waiters.count < maximumQueuedOperations else {
            throw ScreenReportOperationLimiterError.queueFull(limit: maximumQueuedOperations)
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append((id, continuation))
                // Cancellation may have happened after the entry check but before the
                // continuation was registered. Close that window synchronously.
                if Task.isCancelled {
                    let waiter = waiters.removeLast()
                    waiter.continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }

        // `release()` transfers its existing slot to a waiter before resuming it. If
        // cancellation won that race, return the transferred slot instead of letting a
        // canceled download proceed to network and disk I/O.
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    public func cancel(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }

        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    public func release() {
        while !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume()
            return
        }
        activeOperations -= 1
    }

    var activeOperationCount: Int { activeOperations }
    var queuedOperationCount: Int { waiters.count }
}
