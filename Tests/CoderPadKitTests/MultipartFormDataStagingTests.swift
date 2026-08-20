//
//  MultipartFormDataStagingTests.swift
//  CoderPadKitTests
//
//  Regression coverage for question multipart staging cleanup (#139).
//

@testable import CoderPadKit
import Dispatch
import Foundation
import Synchronization
import Testing

@Suite("Question multipart staging cleanup")
struct MultipartFormDataStagingTests {
    @Test
    func `a failed deletion is retained and retried`() async throws {
        let attempts = Mutex(0)
        let folder = MultipartFormData.stagingRoot
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        MultipartFormData.remove(folder, retryAfter: .milliseconds(10)) { _ in
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
    func `leftover sweep removes abandoned staging directories`() throws {
        let folder = MultipartFormData.stagingRoot
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("sensitive upload".utf8).write(to: folder.appending(path: "multipart.body"))
        #expect(FileManager.default.fileExists(atPath: folder.path))

        MultipartFormData.cleanUpLeftovers()

        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test
    func `cleanup cannot delete a body while staging is in progress`() async throws {
        let (created, signalCreated) = AsyncStream<Void>.makeStream()
        let continueWriting = DispatchSemaphore(value: 0)
        let stagedFolder = Mutex<URL?>(nil)
        let staging = Task.detached {
            try MultipartFormData(
                fields: [MultipartFormField(name: "question[title]", value: "In flight")],
                files: [
                    MultipartFormFile(
                        name: "question[zip_file]",
                        filename: "q.zip",
                        contentType: "application/zip",
                        data: Data([0x50, 0x4B, 0x03, 0x04])
                    )
                ],
                afterCreatingFolder: { folder in
                    stagedFolder.withLock { $0 = folder }
                    signalCreated.yield()
                    signalCreated.finish()
                    continueWriting.wait()
                }
            )
        }

        var createdIterator = created.makeAsyncIterator()
        _ = await createdIterator.next()
        defer { continueWriting.signal() }
        let folder = try #require(stagedFolder.withLock { $0 })

        MultipartFormData.cleanUpLeftovers()

        #expect(FileManager.default.fileExists(atPath: folder.path))
        continueWriting.signal()
        let multipart = try await staging.value
        multipart.remove()
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test
    func `remove refuses paths outside the staging root`() throws {
        let outside = FileManager.default.temporaryDirectory
            .appending(path: "OutsideCoderPadQuestionUploads", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }

        MultipartFormData.remove(outside, retryAfter: .milliseconds(10)) { _ in
            Issue.record("removeItem must not run for paths outside the staging root")
        }

        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}
