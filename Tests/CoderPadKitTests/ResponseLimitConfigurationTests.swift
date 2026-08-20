//
//  ResponseLimitConfigurationTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Testing

@Suite("Response limit configuration")
struct ResponseLimitConfigurationTests {
    @Test
    func `negative Screen response limits clamp instead of trapping`() {
        let client = ScreenClient(
            apiKey: "key",
            session: URLSession(configuration: .ephemeral),
            maximumResponseBodyBytes: -1
        )
        #expect(client.maximumResponseBodyBytes == 0)
    }

    @Test
    func `negative Interview history response limits clamp instead of trapping`() {
        let client = CoderPadClient(
            apiKey: "key",
            session: URLSession(configuration: .ephemeral),
            maximumHistoryResponseBodyBytes: -1
        )
        #expect(client.maximumHistoryResponseBodyBytes == 0)
    }

    @Test
    func `validatedResponseBodyLimit rejects negatives for callers that want errors`() {
        #expect(throws: CoderPadError.self) {
            _ = try ScreenClient.validatedResponseBodyLimit(-1)
        }
        #expect(throws: CoderPadError.self) {
            _ = try CoderPadClient.validatedResponseBodyLimit(-1)
        }
    }

    @Test
    func `zero response limits remain constructible`() {
        let screen = ScreenClient(
            apiKey: "key",
            session: URLSession(configuration: .ephemeral),
            maximumResponseBodyBytes: 0
        )
        #expect(screen.maximumResponseBodyBytes == 0)

        let interview = CoderPadClient(
            apiKey: "key",
            session: URLSession(configuration: .ephemeral),
            maximumHistoryResponseBodyBytes: 0
        )
        #expect(interview.maximumHistoryResponseBodyBytes == 0)
    }
}
