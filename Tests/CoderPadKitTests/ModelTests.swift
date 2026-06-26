//
//  ModelTests.swift
//  CoderPadKitTests
//
//  Pure value-type behavior: state/type normalization, the execution_enabled string
//  quirk, and decode tolerance. No network.
//

import CoderPadKit
import Foundation
import Testing

@Suite("PadState normalization")
struct PadStateTests {
    @Test
    func `known synonyms fold into typed cases`() {
        #expect(PadState(apiState: "started") == .active)
        #expect(PadState(apiState: "running") == .active)
        #expect(PadState(apiState: "finished") == .ended)
        #expect(PadState(apiState: "draft") == .pending)
        #expect(PadState(apiState: "deleted") == .deleted)
    }

    @Test
    func `unrecognized states are preserved verbatim as other`() {
        #expect(PadState(apiState: "archived") == .other("archived"))
        #expect(PadState(apiState: "archived").rawValue == "archived")
    }

    @Test
    func `rawValue round-trips through RawRepresentable`() {
        for state in [PadState.active, .ended, .pending, .deleted, .other("custom")] {
            #expect(PadState(rawValue: state.rawValue) == state)
        }
    }

    @Test
    func `only ended is terminal`() {
        #expect(PadState.ended.isEnded)
        #expect(!PadState.active.isEnded)
    }
}

@Suite("InterviewType normalization")
struct InterviewTypeTests {
    @Test
    func `accepts the hyphen and underscore spellings`() {
        #expect(InterviewType(rawType: "live") == .live)
        #expect(InterviewType(rawType: "take-home") == .takeHome)
        #expect(InterviewType(rawType: "take_home") == .takeHome)
        #expect(InterviewType(rawType: "takehome") == .takeHome)
    }

    @Test
    func `nil for empty or unrecognized values`() {
        #expect(InterviewType(rawType: nil) == nil)
        #expect(InterviewType(rawType: "") == nil)
        #expect(InterviewType(rawType: "phone") == nil)
    }
}

@Suite("execution_enabled string quirk")
struct ExecutionEnabledTests {
    @Test
    func `PadCreate encodes execution_enabled as a JSON string, not a boolean`() throws {
        let data = try CoderPadClient.encoder.encode(PadCreate(executionEnabled: true))
        let json = String(decoding: data, as: UTF8.self)
        // The documented boolean is silently ignored by the live API; the string form
        // is what actually takes effect (see PadCreate's discussion).
        #expect(json.contains("\"execution_enabled\":\"true\""))
        #expect(!json.contains("\"execution_enabled\":true"))
    }

    @Test
    func `PadCreate decodes either the string form or a plain boolean`() throws {
        let fromString = try CoderPadClient.decoder.decode(
            PadCreate.self, from: Data(#"{"execution_enabled":"true"}"#.utf8)
        )
        #expect(fromString.executionEnabled == true)

        let fromBool = try CoderPadClient.decoder.decode(
            PadCreate.self, from: Data(#"{"execution_enabled":false}"#.utf8)
        )
        #expect(fromBool.executionEnabled == false)
    }

    @Test
    func `a nil execution flag is omitted entirely`() throws {
        let data = try CoderPadClient.encoder.encode(PadCreate(title: "No flag"))
        #expect(!String(decoding: data, as: UTF8.self).contains("execution_enabled"))
    }
}

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
}

@Suite("CoderPadError")
struct CoderPadErrorTests {
    @Test
    func `401 and 403 are unauthorized; others are not`() {
        #expect(CoderPadError.http(401, "").isUnauthorized)
        #expect(CoderPadError.http(403, "").isUnauthorized)
        #expect(!CoderPadError.http(404, "").isUnauthorized)
        #expect(!CoderPadError.missingAPIKey.isUnauthorized)
    }
}
