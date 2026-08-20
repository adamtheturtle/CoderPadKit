//
//  ScreenErrorBodyDecodingTests.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen error body decoding")
struct ScreenErrorBodyDecodingTests {
    @Test
    func `a truncated multibyte scalar still preserves the readable ASCII prefix`() throws {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var bytes = Data(repeating: UInt8(ascii: "x"), count: ScreenClient.maximumErrorBodyBytes - 1)
        // U+1F600 encoding is F0 9F 98 80; splitting after the first byte of that
        // sequence used to make `String(bytes:encoding:)` return nil (#112).
        bytes.append(0xF0)
        try bytes.write(to: fileURL)

        let body = try ScreenClient.reportErrorBody(at: fileURL)

        #expect(body.hasPrefix(String(repeating: "x", count: ScreenClient.maximumErrorBodyBytes - 1)))
        #expect(!body.isEmpty)
        // Lossy UTF-8 decoding may emit U+FFFD for the split scalar; the important
        // property is that the ASCII prefix survives rather than becoming "".
        #expect(body.contains("x"))
    }
}
