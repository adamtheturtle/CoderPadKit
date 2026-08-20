//
//  OpenableHTTPSURLTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Openable HTTPS URLs")
struct OpenableHTTPSURLTests {
    @Test(arguments: [
        "https://app.coderpad.io/pads/ABC",
        "https://eu.app.coderpad.io/playback/ABC?token=1",
        "https://www.codingame.com/work/candidates/tests/1"
    ])
    func `absolute HTTPS links are accepted`(raw: String) {
        #expect(OpenableHTTPSURL.parse(raw)?.absoluteString == raw
            || OpenableHTTPSURL.parse(raw) != nil)
    }

    @Test(arguments: [
        "javascript:alert(1)",
        "file:///etc/passwd",
        "http://app.coderpad.io/pads/ABC",
        "/relative/path",
        "pads/ABC",
        "https://user:pass@app.coderpad.io/pads/ABC",
        "https://user@app.coderpad.io/pads/ABC",
        "   ",
        ""
    ])
    func `relative and non-web schemes are rejected`(raw: String) {
        #expect(OpenableHTTPSURL.parse(raw) == nil)
    }

    @Test
    func `Pad webURL and playbackURL require openable HTTPS`() throws {
        let safe = try CoderPadClient.decoder.decode(
            Pad.self,
            from: Data(
                #"{"id":"P1","url":"https://app.coderpad.io/pads/P1","playback":"https://app.coderpad.io/playback/P1"}"#
                    .utf8
            )
        )
        #expect(safe.webURL?.host == "app.coderpad.io")
        #expect(safe.playbackURL?.path.contains("playback") == true)

        let unsafe = try CoderPadClient.decoder.decode(
            Pad.self,
            from: Data(#"{"id":"P2","url":"javascript:alert(1)","playback":"file:///tmp/x"}"#.utf8)
        )
        #expect(unsafe.webURL == nil)
        #expect(unsafe.playbackURL == nil)
    }

    @Test
    func `Screen session and invitation expose openable accessors`() throws {
        let session = try JSONDecoder().decode(
            ScreenTestSession.self,
            from: Data(
                #"""
                {
                  "id": 1,
                  "url": "https://app.coderpad.io/screen/tests/1",
                  "test_url": "javascript:evil"
                }
                """#.utf8
            )
        )
        #expect(session.openableURL?.host == "app.coderpad.io")
        #expect(session.openableTestURL == nil)
        #expect(session.testURL == "javascript:evil")

        let invitation = try JSONDecoder().decode(
            ScreenInvitationResult.self,
            from: Data(#"{"test_url":"https://app.coderpad.io/screen/demo/tests/1"}"#.utf8)
        )
        #expect(invitation.openableTestURL?.host == "app.coderpad.io")
    }
}
