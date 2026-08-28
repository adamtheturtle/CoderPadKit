//
//  DecodeToleranceTests.swift
//  CoderPadKitTests
//
//  Decode tolerance for pads, questions, and pad environments.
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Decode tolerance")
struct DecodeToleranceTests {
    @Test
    func `Pad drops null participants rather than failing the whole array`() throws {
        let json = Data(#"{"id":"P1","participants":["Real Person",null,"Another"]}"#.utf8)
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: json)
        #expect(pad.participants == ["Real Person", "Another"])
    }

    @Test
    func `Pad tolerates missing optional fields, defaulting sensibly`() throws {
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: Data(#"{"id":"P2"}"#.utf8))
        #expect(pad.id == "P2")
        #expect(pad.title.isEmpty)
        #expect(pad.state == "unknown")
        #expect(pad.participants.isEmpty)
        #expect(pad.language == nil)
    }

    @Test
    func `Pad requires an active environment ID to appear exactly once`() throws {
        let valid = try CoderPadClient.decoder.decode(
            Pad.self,
            from: Data(
                #"{"id":"P-env","active_environment_id":2,"pad_environment_ids":[1,2,3]}"#.utf8
            )
        )
        #expect(valid.activeEnvironmentID == 2)

        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Pad.self,
                from: Data(
                    #"{"id":"P-missing","active_environment_id":9,"pad_environment_ids":[1,2]}"#.utf8
                )
            )
        }

        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(
                Pad.self,
                from: Data(
                    #"{"id":"P-dup","active_environment_id":2,"pad_environment_ids":[2,2]}"#.utf8
                )
            )
        }
    }

    @Test
    func `Pad and Question parse both fractional and whole-second timestamps`() throws {
        let fractional = try CoderPadClient.decoder.decode(
            Pad.self, from: Data(#"{"id":"P3","created_at":"2026-06-10T08:00:00.500Z"}"#.utf8)
        )
        #expect(fractional.createdAt != nil)

        let whole = try CoderPadClient.decoder.decode(
            Pad.self, from: Data(#"{"id":"P4","created_at":"2026-06-10T08:00:00Z"}"#.utf8)
        )
        #expect(whole.createdAt != nil)
    }


    /// Reported, never fatal. `PadsPage.pads` is a plain `[Pad]`, so throwing here
    /// failed the whole page: one pad with skewed timestamps blanked a user's entire
    /// list over a discrepancy that does not impair anything they were shown.
    @Test
    func `Pad reports impossible lifecycle timestamps instead of failing to decode`() throws {
        func pad(_ json: String) throws -> Pad {
            try CoderPadClient.decoder.decode(Pad.self, from: Data(json.utf8))
        }

        let consistent = try pad(#"""
        {
          "id": "P-ended",
          "state": "ended",
          "created_at": "2026-06-10T08:00:00Z",
          "updated_at": "2026-06-10T10:00:00Z",
          "ended_at": "2026-06-10T09:00:00Z"
        }
        """#)
        #expect(consistent.endedAt != nil)
        #expect(consistent.lifecycleInconsistencies.isEmpty)
        #expect(consistent.lifecycleDiagnostic == nil)

        let updatedEarly = try pad(#"""
        {
          "id": "P-update-before-create",
          "created_at": "2026-06-10T09:00:00Z",
          "updated_at": "2026-06-10T08:00:00Z"
        }
        """#)
        #expect(updatedEarly.lifecycleInconsistencies == [.updatedBeforeCreated])
        #expect(updatedEarly.updatedAt != nil)

        let endedEarly = try pad(#"""
        {
          "id": "P-end-before-create",
          "state": "ended",
          "created_at": "2026-06-10T09:00:00Z",
          "ended_at": "2026-06-10T08:00:00Z"
        }
        """#)
        #expect(endedEarly.lifecycleInconsistencies == [.endedBeforeCreated])
        #expect(endedEarly.isEnded)

        let endedWhileActive = try pad(#"""
        {
          "id": "P-active-ended",
          "state": "started",
          "ended_at": "2026-06-10T09:00:00Z"
        }
        """#)
        #expect(endedWhileActive.lifecycleInconsistencies == [.endedWhileActive])
        // `isEnded` prefers the explicit timestamp, as its own contract says.
        #expect(endedWhileActive.isEnded)
        #expect(endedWhileActive.lifecycleDiagnostic?.contains("active or pending") == true)
    }

    /// Every per-record check in `Pad.init(from:)` rejects the record it applies to.
    /// A plain `[Pad]` turned any one of them into a failure of the whole page — the
    /// caller saw an error and no pads at all when 49 of 50 were fine.
    @Test
    func `a page of pads drops an unusable member instead of failing`() throws {
        let pads = try CoderPadClient.decoder.decode(
            PadsPage.self,
            from: Data(#"""
            {
              "pads": [
                {"id": "P-good", "state": "ended"},
                {"id": "../escape", "state": "ended"},
                {"id": "P-also-good", "state": "started"}
              ]
            }
            """#.utf8)
        ).pads

        #expect(pads.map(\.id) == ["P-good", "P-also-good"])
    }

    /// A whole page of pads survives one member with contradictory timestamps.
    @Test
    func `a page of pads decodes when one member is inconsistent`() throws {
        struct Page: Decodable { let pads: [Pad] }

        let page = try CoderPadClient.decoder.decode(Page.self, from: Data(#"""
        {
          "pads": [
            {"id": "P-good", "state": "ended"},
            {"id": "P-bad", "state": "started", "ended_at": "2026-06-10T09:00:00Z"},
            {"id": "P-also-good", "state": "started"}
          ]
        }
        """#.utf8))

        #expect(page.pads.map(\.id) == ["P-good", "P-bad", "P-also-good"])
        #expect(page.pads[1].lifecycleInconsistencies == [.endedWhileActive])
    }

    @Test
    func `Question reports an out-of-order updated_at instead of failing to decode`() throws {
        let question = try CoderPadClient.decoder.decode(Question.self, from: Data(#"""
        {
          "id": 7,
          "created_at": "2026-06-10T09:00:00Z",
          "updated_at": "2026-06-10T08:00:00Z"
        }
        """#.utf8))

        #expect(question.id == 7)
        #expect(question.lifecycleInconsistencies == [.updatedBeforeCreated])
    }

    @Test
    func `Pad retains empirically observed access and notification metadata`() throws {
        let json = Data(
            #"""
            {
              "id": "P5",
              "restrict_interviewer_access": true,
              "pad_interviewer_notifications": [{
                "id": 42,
                "title": "Code pasted",
                "message": "The candidate pasted code from outside the pad.",
                "priority": 2,
                "request_id": "request-42",
                "auto_dismissed": false,
                "dismissed_at": null,
                "useful": null,
                "created_at": "2026-07-16T10:00:00Z",
                "updated_at": "2026-07-16T10:01:00Z"
              }]
            }
            """#.utf8
        )
        let pad = try CoderPadClient.decoder.decode(Pad.self, from: json)
        let notification = try #require(pad.padInterviewerNotifications.first)

        #expect(pad.restrictInterviewerAccess == true)
        #expect(notification.id == 42)
        #expect(notification.title == "Code pasted")
        #expect(notification.message.contains("outside the pad"))
        #expect(notification.priority == 2)
        #expect(notification.requestID == "request-42")
        #expect(!notification.autoDismissed)
        #expect(notification.dismissedAt == nil)
        #expect(notification.useful == nil)
        #expect(notification.createdAt != nil)
        #expect(notification.updatedAt != nil)
    }

    @Test
    func `notification priority accepts a numeric string and ignores unknown shapes`() throws {
        let numeric = try JSONDecoder().decode(
            PadInterviewerNotification.self,
            from: Data(#"{"id":1,"priority":"3"}"#.utf8)
        )
        let unknown = try JSONDecoder().decode(
            PadInterviewerNotification.self,
            from: Data(#"{"id":2,"priority":{"level":"high"}}"#.utf8)
        )

        #expect(numeric.priority == 3)
        #expect(unknown.priority == nil)
    }
}
