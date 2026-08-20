//
//  PadMutationValidationTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import Foundation
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Pad mutation validation")
struct PadMutationValidationTests {
    @Test
    func `create encoding rejects contents combined with a question`() {
        #expect(throws: PadMutationValidationError.self) {
            _ = try CoderPadClient.encoder.encode(
                PadCreate(contents: "starter", questionID: 42)
            )
        }
    }

    @Test
    func `update encoding rejects contents combined with a question`() {
        #expect(throws: PadMutationValidationError.self) {
            _ = try CoderPadClient.encoder.encode(
                PadUpdate(id: "PAD123", contents: "starter", questionID: 42)
            )
        }
    }

    @Test
    func `create and update permit either source by itself`() throws {
        _ = try CoderPadClient.encoder.encode(PadCreate(contents: "starter"))
        _ = try CoderPadClient.encoder.encode(PadCreate(questionID: 42))
        _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", contents: "starter"))
        _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", questionID: 42))
    }

    @Test
    func `client mutations reject the conflict before starting a request`() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnexpectedPadMutationURLProtocol.self]
        let client = CoderPadClient(
            apiKey: "secret",
            session: URLSession(configuration: configuration)
        )

        await #expect(throws: PadMutationValidationError.self) {
            _ = try await client.createPad(PadCreate(contents: "starter", questionID: 42))
        }
        await #expect(throws: PadMutationValidationError.self) {
            _ = try await client.updatePad(
                PadUpdate(id: "PAD123", contents: "starter", questionID: 42)
            )
        }
    }

    @Test
    func `update encoding rejects ended and deleted together`() throws {
        #expect(throws: PadMutationValidationError.endedAndDeletedTogether) {
            _ = try CoderPadClient.encoder.encode(
                PadUpdate(id: "PAD123", ended: true, deleted: true)
            )
        }
        _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", ended: true))
        _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", deleted: true))
    }

    @Test(arguments: ["not-an-email", "no-at-sign.example.com", "spaced address@example.com", ""])
    func `create rejects an implausible owner email`(_ ownerEmail: String) {
        #expect(throws: PadMutationValidationError.implausibleOwnerEmail) {
            _ = try CoderPadClient.encoder.encode(PadCreate(ownerEmail: ownerEmail))
        }
    }

    @Test
    func `update rejects an implausible owner email`() {
        #expect(throws: PadMutationValidationError.implausibleOwnerEmail) {
            _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", ownerEmail: "nope"))
        }
    }

    @Test
    func `a plausible owner email is trimmed and domain-lowercased before encoding`() throws {
        let data = try CoderPadClient.encoder.encode(
            PadCreate(ownerEmail: "  Interviewer@EXAMPLE.COM  ")
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(root["owner_email"] as? String == "Interviewer@example.com")
    }

    @Test
    func `an absent owner email is omitted rather than rejected`() throws {
        _ = try CoderPadClient.encoder.encode(PadCreate())
        _ = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123"))
    }

    @Test(arguments: ["", "not-a-uuid", "team-frontdesk", " 9d3b1e4a-3d4d-4b8c-9d2e-6a2d2f9c8b7a"])
    func `create rejects a team ID that is not a canonical UUID`(_ teamID: String) {
        #expect(throws: PadMutationValidationError.invalidTeamID) {
            _ = try CoderPadClient.encoder.encode(PadCreate(teamID: teamID))
        }
    }

    @Test
    func `create accepts a canonical UUID team ID`() throws {
        let uuid = UUID().uuidString
        let data = try CoderPadClient.encoder.encode(PadCreate(teamID: uuid))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(root["team_id"] as? String == uuid)
    }

    @Test
    func `an absent team ID is omitted rather than rejected`() throws {
        _ = try CoderPadClient.encoder.encode(PadCreate())
    }

    @Test
    func `update encoding omits id from the JSON body`() throws {
        let data = try CoderPadClient.encoder.encode(PadUpdate(id: "PAD123", title: "Renamed"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(root["id"] == nil)
        #expect(root["title"] as? String == "Renamed")
    }

    @Test
    func `fromQuestion carries the title, language, and question but leaves defaults nil`() throws {
        let json = Data(#"{"id":55,"title":"Two Sum","language":"python3"}"#.utf8)
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)

        let padCreate = PadCreate.fromQuestion(question)

        #expect(padCreate.title == "Two Sum")
        #expect(padCreate.language == "python3")
        #expect(padCreate.questionID == 55)
        #expect(padCreate.isPrivate == nil)
        #expect(padCreate.executionEnabled == nil)
        #expect(padCreate.ownerEmail == nil)
        #expect(padCreate.contents == nil)

        let data = try CoderPadClient.encoder.encode(padCreate)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["private"] == nil)
        #expect(root["execution_enabled"] == nil)
    }
}

private final nonisolated class UnexpectedPadMutationURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
    }

    override func stopLoading() {}
}
