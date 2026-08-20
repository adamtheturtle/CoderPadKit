//
//  coderpadTests+ScreenMetrics.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen report metrics")
struct ScreenReportMetricTests {
    @Test(arguments: [
        #"{"score":-0.1}"#,
        #"{"score":100.1}"#,
        #"{"comparative_score":-1}"#,
        #"{"comparative_score":101}"#
    ])
    func `report rejects percentages outside zero through one hundred`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: [0.0, 50.5, 100.0])
    func `report accepts percentage boundaries`(score: Double) throws {
        let json = #"{"score":\#(score),"comparative_score":\#(score)}"#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
        #expect(report.score == score)
        #expect(report.comparativeScore == score)
    }

    @Test
    func `invalid nested percentages drop only their malformed entries`() throws {
        let json = #"{"technologies":{"Valid":{"score":50},"Invalid":{"score":120}}}"#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.technologies["Valid"]?.score == 50)
        #expect(report.technologies["Invalid"] == nil)
    }

    @Test
    func `breakdown keys are normalized bounded and collision safe`() throws {
        let longKey = "Long " + String(repeating: "x", count: 140)
        let object: [String: Any] = [
            "technologies": [
                " Java\n\t": ["score": 10],
                "Java": ["score": 20],
                "\u{200B}": ["score": 30],
                longKey: ["score": 40]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        let report = try JSONDecoder().decode(ScreenReport.self, from: data)

        #expect(report.technologies.keys.contains("Java"))
        #expect(report.technologies.keys.contains(where: { $0.count == 100 }))
        #expect(report.technologies.keys.allSatisfy { !$0.contains("\n") && !$0.contains("\t") })
        #expect(report.technologies.count == 2)
        #expect(report.omittedBreakdownEntries == 2)
    }

    @Test
    func `report collections and warning values are bounded`() throws {
        let technologies = Dictionary(uniqueKeysWithValues: (0 ..< 120).map {
            ("Technology \($0)", ["score": 50])
        })
        let warnings = [String(repeating: "x", count: 600)]
            + (0 ..< 120).map { " Warning \($0)\n" }
        let data = try JSONSerialization.data(withJSONObject: [
            "technologies": technologies,
            "warnings": warnings
        ])
        let report = try JSONDecoder().decode(ScreenReport.self, from: data)

        #expect(report.technologies.count == 100)
        #expect(report.omittedBreakdownEntries == 20)
        #expect(report.warnings.count == 100)
        #expect(report.omittedWarningCount == 21)
        #expect(report.warnings.allSatisfy { $0.count <= 500 && !$0.contains("\n") })
    }

    @Test
    func `valid technologies after early malformed keys are still retained`() throws {
        var technologies: [String: Any] = [:]
        for index in 0 ..< 100 {
            // Lexicographically early keys that fail value decoding.
            technologies[String(format: "A%03d", index)] = ["score": 120]
        }
        technologies["Valid"] = ["score": 50]

        let data = try JSONSerialization.data(withJSONObject: ["technologies": technologies])
        let report = try JSONDecoder().decode(ScreenReport.self, from: data)

        #expect(report.technologies["Valid"]?.score == 50)
        #expect(report.technologies.count == 1)
        #expect(report.omittedBreakdownEntries == 100)
    }

    @Test(arguments: [
        #"{"duration":-1}"#,
        #"{"points":-1}"#,
        #"{"total_duration":-1}"#,
        #"{"total_points":-1}"#
    ])
    func `report rejects negative count and duration metrics`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
        }
    }

    @Test
    func `negative nested points drop only their malformed entries`() throws {
        let json = #"{"technologies":{"Valid":{"points":0},"Invalid":{"total_points":-1}}}"#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.technologies["Valid"]?.points == 0)
        #expect(report.technologies["Invalid"] == nil)
    }

    @Test
    func `report rejects points above total_points`() {
        let json = #"{"points":500,"total_points":100}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
        }
    }

    @Test
    func `report rejects duration above total_duration`() {
        let json = #"{"duration":500,"total_duration":100}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
        }
    }

    @Test(arguments: [(50, 100), (100, 100), (0, 0)])
    func `report accepts points and duration at or below their totals`(points: Int, totalPoints: Int) throws {
        let json = #"{"points":\#(points),"total_points":\#(totalPoints),"#
            + #""duration":\#(points),"total_duration":\#(totalPoints)}"#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.points == points)
        #expect(report.totalPoints == totalPoints)
        #expect(report.duration == points)
        #expect(report.totalDuration == totalPoints)
    }

    @Test
    func `technology points above total_points are dropped rather than failing the report`() throws {
        let json = #"{"technologies":{"Valid":{"points":10,"total_points":20},"#
            + #""Invalid":{"points":500,"total_points":100}}}"#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.technologies["Valid"]?.points == 10)
        #expect(report.technologies["Invalid"] == nil)
    }

    @Test
    func `skill points above total_points are dropped rather than failing the technology`() throws {
        let json = #"""
        {"technologies":{"Java":{"skills":{
            "Valid":{"points":10,"total_points":20},
            "Invalid":{"points":500,"total_points":100}
        }}}}
        """#
        let report = try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))

        #expect(report.technologies["Java"]?.skills["Valid"]?.points == 10)
        #expect(report.technologies["Java"]?.skills["Invalid"] == nil)
    }

    @Test
    func `present numeric report fields reject the wrong JSON type`() {
        let fields = ["duration", "points", "score", "total_duration", "total_points", "comparative_score"]
        for field in fields {
            let json = "{\"\(field)\":\"unknown\"}"
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(ScreenReport.self, from: Data(json.utf8))
            }
        }

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ScreenReport.self,
                from: Data(#"{"community_stats":[1,"unknown"]}"#.utf8)
            )
        }
    }

    @Test
    func `report rejects negative community statistic buckets`() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScreenReport.self, from: Data(#"{"community_stats":[2,-1,4]}"#.utf8))
        }
    }

    @Test
    func `report accepts nonnegative community statistic buckets`() throws {
        let report = try JSONDecoder().decode(
            ScreenReport.self,
            from: Data(#"{"community_stats":[0,1,2]}"#.utf8)
        )
        #expect(report.communityStats == [0, 1, 2])
    }

    @Test
    func `report rejects oversized community statistic arrays`() {
        let buckets = Array(repeating: 1, count: 101).map(String.init).joined(separator: ",")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ScreenReport.self,
                from: Data(#"{"community_stats":[\#(buckets)]}"#.utf8)
            )
        }
    }
}
