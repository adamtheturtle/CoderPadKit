//
//  ScreenReportFilesTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Screen report files")
struct ScreenReportFilesTests {
    @Test
    func `a failed deletion is retained and retried`() async throws {
        let attempts = Mutex(0)
        let folder = ScreenReportFiles.stagingRoot.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let report = folder.appending(path: "report.pdf")

        ScreenReportFiles.remove(report, retryAfter: .milliseconds(10)) { _ in
            let attempt = attempts.withLock { count in
                count += 1
                return count
            }
            if attempt == 1 { throw CocoaError(.fileWriteNoPermission) }
        }

        for _ in 0 ..< 100 where attempts.withLock({ $0 }) < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(attempts.withLock { $0 } == 2)
    }
}
