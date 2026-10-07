import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Pad analytics")
struct PadAnalyticsTests {
    @Test
    func `ordinary pads keep analytics absent`() throws {
        let pad = try CoderPadClient.makeDecoder().decode(Pad.self, from: Data(#"{"id":"pad-1"}"#.utf8))
        #expect(pad.interviewHighlights == nil)
        #expect(pad.interviewOutline == nil)
        #expect(pad.transcript == nil)
        #expect(pad.transcriptSourceUnavailable == nil)
        #expect(pad.reviewReports == nil)
    }

    @Test
    func `empty transcripts and reports remain distinct from absence`() throws {
        let data = Data(
            #"{"id":"pad-1","transcript":[],"review_reports":[],"transcript_source_unavailable":true}"#.utf8
        )
        let pad = try CoderPadClient.makeDecoder().decode(Pad.self, from: data)
        #expect(pad.transcript == [])
        #expect(pad.reviewReports == [])
        #expect(pad.transcriptSourceUnavailable == true)
        let edited = pad.applying(title: "Renamed")
        #expect(edited.transcript == [])
        #expect(edited.reviewReports == [])
        #expect(edited.transcriptSourceUnavailable == true)
    }

    @Test
    func `complete analytics preserve transcript identities and review metadata`() throws {
        let data = Data(#"""
        {"id":"pad-1","interview_highlights":"Boundary cases explained",
         "interview_outline":{"sections":[{"title":"Design","offset":1500}],"complete":true,"extra":null},
         "transcript_source_unavailable":false,
         "transcript":[
          {"id":"spoken","kind":"transcript","speaker_name":"Ada","speaker_role":"candidate",
           "text":"Check an empty page.","timestamp":1780680000000},
          {"id":"system","kind":"system_message","speaker_name":null,"speaker_role":null,
           "text":"Interview ended","timestamp":1780680002000}],
         "review_reports":[{"id":"review-1","status":"completed","title":"Review","prompt":"Evaluate correctness",
          "report":"Passed boundary checks","summary":"Correct","icon":"check","error":null,"user_id":101,
          "file_paths":["src/main.swift"],"created_at":"2026-06-10T08:00:00Z","updated_at":"2026-06-10T08:02:00Z"}]}
        """#.utf8)
        let decoder = CoderPadClient.makeDecoder()
        let pad = try decoder.decode(Pad.self, from: data)
        #expect(pad.interviewHighlights == "Boundary cases explained")
        #expect(pad.interviewOutline == .object([
            "sections": .array([.object(["title": .string("Design"), "offset": .number(1500)])]),
            "complete": .bool(true), "extra": .null
        ]))
        #expect(pad.transcriptSourceUnavailable == false)
        #expect(pad.transcript == [
            TranscriptEntry(id: "spoken", kind: .transcript, speakerName: "Ada", speakerRole: "candidate",
                            text: "Check an empty page.", timestamp: 1_780_680_000_000),
            TranscriptEntry(id: "system", kind: .systemMessage, text: "Interview ended", timestamp: 1_780_680_002_000)
        ])
        let report = try #require(pad.reviewReports?.first)
        #expect(report.id == "review-1")
        #expect(report.status == "completed")
        #expect(report.title == "Review")
        #expect(report.prompt == "Evaluate correctness")
        #expect(report.report == "Passed boundary checks")
        #expect(report.summary == "Correct")
        #expect(report.icon == "check")
        #expect(report.error == nil)
        #expect(report.userID == 101)
        #expect(report.filePaths == ["src/main.swift"])
        #expect(report.createdAt == ISO8601DateFormatter().date(from: "2026-06-10T08:00:00Z"))
        #expect(report.updatedAt == ISO8601DateFormatter().date(from: "2026-06-10T08:02:00Z"))
        let encoded = try CoderPadClient.makeEncoder().encode(pad)
        let roundTrip = try decoder.decode(Pad.self, from: encoded)
        #expect(roundTrip.interviewOutline == pad.interviewOutline)
        #expect(roundTrip.transcript == pad.transcript)
        #expect(roundTrip.reviewReports == pad.reviewReports)
        let edited = pad.applying(isPrivate: false)
        #expect(edited.interviewHighlights == pad.interviewHighlights)
        #expect(edited.interviewOutline == pad.interviewOutline)
        #expect(edited.transcript == pad.transcript)
        #expect(edited.transcriptSourceUnavailable == false)
        #expect(edited.reviewReports == pad.reviewReports)
    }

    @Test
    func `structured JSON retains nested values and decimal precision`() throws {
        let decoder = JSONDecoder()
        let input = Data(#"{"values":[false,null,"text",9007199254740993,0.125,{}]}"#.utf8)
        let result = try decoder.decode(JSONValue.self, from: input)
        let fraction = try #require(Decimal(string: "0.125"))
        #expect(result == .object([
            "values": .array([.bool(false), .null, .string("text"),
                              .number(9_007_199_254_740_993), .number(fraction), .object([:])])
        ]))
        let encoded = try JSONEncoder().encode(result)
        #expect(try decoder.decode(JSONValue.self, from: encoded) == result)
    }

    @Test
    func `mock detail routes return transcripts and owner reports without changing lists`() async throws {
        let client = CoderPadClient.mock(key: "analytics-\(UUID().uuidString)")
        let pads = try await client.listPads()
        #expect(pads.allSatisfy { $0.transcript == nil && $0.reviewReports == nil })
        let spoken = try await client.getPad(id: "DEMOXYZ2")
        #expect(spoken.interviewHighlights == "The candidate explained pagination and boundary cases.")
        #expect(spoken.transcript?.map(\.kind) == [.transcript, .systemMessage])
        #expect(spoken.transcriptSourceUnavailable == false)
        #expect(spoken.reviewReports == nil)
        let owner = try await client.getPad(id: "DEMOSWFT5")
        #expect(owner.transcript == [])
        #expect(owner.transcriptSourceUnavailable == true)
        #expect(owner.reviewReports?.map(\.status) == ["pending", "error"])
        #expect(owner.reviewReports?[0].report == nil)
        #expect(owner.reviewReports?[0].filePaths == [])
        #expect(owner.reviewReports?[1].error == "Review generation failed")
        let changedOwner = try await client.updatePad(PadUpdate(id: owner.id, ownerEmail: "another@example.com"))
        #expect(changedOwner.reviewReports == nil)
        #expect(changedOwner.transcriptSourceUnavailable == true)
    }

    @Test
    func `review initializer and wire names round trip`() throws {
        let review = ReviewReport(id: "pending", status: "pending", userID: 0, filePaths: [])
        let encoded = try CoderPadClient.makeEncoder().encode(review)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object.keys.sorted() == ["file_paths", "id", "status", "user_id"])
        #expect(try CoderPadClient.makeDecoder().decode(ReviewReport.self, from: encoded) == review)
    }
}
