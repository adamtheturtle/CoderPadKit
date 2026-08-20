//
//  ScreenWarningSanitizationTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen warning sanitization")
struct ScreenWarningSanitizationTests {
    @Test
    func `bidirectional format controls are scrubbed from warnings`() throws {
        let json = Data(#"""
        {
          "score": 50,
          "warnings": ["Left full screen\u202E once", "ok"]
        }
        """#.utf8)
        let report = try JSONDecoder().decode(ScreenReport.self, from: json)
        #expect(report.warnings.count == 2)
        #expect(!report.warnings[0].contains("\u{202E}"))
        #expect(report.warnings[0].contains("Left full screen"))
        #expect(report.warnings[1] == "ok")
    }

    @Test
    func `warnings that are only format controls are discarded`() throws {
        let json = Data(#"""
        {"warnings": ["\u202A\u202C", "kept"]}
        """#.utf8)
        let report = try JSONDecoder().decode(ScreenReport.self, from: json)
        #expect(report.warnings == ["kept"])
        #expect(report.omittedWarningCount == 1)
    }
}
