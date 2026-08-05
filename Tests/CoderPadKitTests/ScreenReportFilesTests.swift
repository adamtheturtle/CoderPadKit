//
//  ScreenReportFilesTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import CoderPadKitMock
import Dispatch
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

    @Test
    func `outside schedule with a colliding name cannot replace legitimate cleanup`() async throws {
        let name = UUID().uuidString
        let folder = ScreenReportFiles.stagingRoot.appending(path: name, directoryHint: .isDirectory)
        let report = folder.appending(path: "report.pdf")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("sensitive report".utf8).write(to: report)
        defer { try? FileManager.default.removeItem(at: folder) }

        ScreenReportFiles.scheduleRemoval(of: report, after: .milliseconds(30))
        let outside = FileManager.default.temporaryDirectory
            .appending(path: "OutsideScreenReports", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
            .appending(path: "attacker.pdf")
        ScreenReportFiles.scheduleRemoval(of: outside, after: .milliseconds(1))

        for _ in 0 ..< 100 where FileManager.default.fileExists(atPath: folder.path) {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test
    func `cleanup cannot delete a report while staging is in progress`() async throws {
        let data = try await ScreenClient.mock(key: "stage-race-\(UUID().uuidString)")
            .testReport(id: 5001)
        let (created, signalCreated) = AsyncStream<Void>.makeStream()
        let continueWriting = DispatchSemaphore(value: 0)
        let stagedFolder = Mutex<URL?>(nil)
        let staging = Task.detached {
            try ScreenReportFiles.stage(data, testID: 5001) { folder in
                stagedFolder.withLock { $0 = folder }
                signalCreated.yield()
                signalCreated.finish()
                continueWriting.wait()
            }
        }

        var createdIterator = created.makeAsyncIterator()
        _ = await createdIterator.next()
        defer { continueWriting.signal() }
        let folder = try #require(stagedFolder.withLock { $0 })

        ScreenReportFiles.cleanUpLeftovers()

        #expect(FileManager.default.fileExists(atPath: folder.path))
        continueWriting.signal()
        let report = try await staging.value
        ScreenReportFiles.remove(report)
    }
}
