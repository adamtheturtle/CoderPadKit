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
}

private final nonisolated class UnexpectedPadMutationURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
    }

    override func stopLoading() {}
}
