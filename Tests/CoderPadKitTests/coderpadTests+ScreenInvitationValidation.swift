//
//  coderpadTests+ScreenInvitationValidation.swift
//  coderpadTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen invitation and report request validation")
struct ScreenInvitationAndReportValidationTests {
    @Test
    func `sendInvitation rejects email delivery without a candidate email`() {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.validatedInvitation(
                ScreenInvitation(candidateEmail: nil, sendInvitationEmail: true)
            )
        }
    }

    @Test
    func `sendInvitation accepts delivery when a candidate email is present`() throws {
        let invitation = try ScreenClient.validatedInvitation(
            ScreenInvitation(
                candidateEmail: " Candidate@Example.COM ",
                recruiterEmail: " Recruiter@Example.COM ",
                sendInvitationEmail: true
            )
        )
        #expect(invitation.candidateEmail == "Candidate@example.com")
        #expect(invitation.recruiterEmail == "Recruiter@example.com")
    }

    @Test(arguments: [
        ScreenInvitation(candidateEmail: "not-an-email"),
        ScreenInvitation(recruiterEmail: "also invalid")
    ])
    func `sendInvitation rejects implausible emails`(invitation: ScreenInvitation) {
        #expect(throws: CoderPadError.self) {
            try ScreenClient.validatedInvitation(invitation)
        }
    }

    @Test
    func `sendInvitation allows omitting candidate email when not emailing`() throws {
        let invitation = try ScreenClient.validatedInvitation(
            ScreenInvitation(candidateEmail: nil, sendInvitationEmail: false)
        )
        #expect(invitation.candidateEmail == nil)
        #expect(invitation.sendInvitationEmail == false)
    }

    @Test
    func `report type wire values are the documented variants`() {
        #expect(ScreenReportType.full.rawValue == "full")
        #expect(ScreenReportType.simplified.rawValue == "simplified")
        #expect(Set(ScreenReportType.allCases.map(\.rawValue)) == ["full", "simplified"])
    }
}
