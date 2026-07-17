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
    func `live is an interview type not a lifecycle state`() {
        // "live" belongs to InterviewType (format), not PadState (lifecycle), so it
        // must not fold into .active; it falls through like any unrecognized state.
        #expect(PadState(apiState: "live") == .other("live"))
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
    func `environment file retains binary when contents are unavailable`() throws {
        let json = Data(
            #"{"id":7,"file_contents":[{"path":"image.png","contents":null,"binary":true}]}"#.utf8
        )
        let environment = try CoderPadClient.decoder.decode(PadEnvironment.self, from: json)
        let file = try #require(environment.fileContents.first)

        #expect(file.path == "image.png")
        #expect(file.contents == nil)
        #expect(file.binary == true)
    }

    @Test
    func `Question retains an empirically observed custom database schema`() throws {
        let json = Data(
            #"""
            {
              "id": 9,
              "custom_database": {
                "id": 71,
                "title": "Orders",
                "description": "Synthetic order data",
                "language": "postgresql",
                "schema": "CREATE TABLE orders (id INTEGER PRIMARY KEY);",
                "schema_json": {
                  "arrangement": [{
                    "name": "orders",
                    "columns": [
                      {"name":"id","type":"INTEGER","pk":true,"nn":true},
                      {"name":"note","type":"TEXT","pk":false,"nn":false}
                    ]
                  }]
                }
              }
            }
            """#.utf8
        )
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)
        let database = try #require(question.customDatabase)
        let table = try #require(database.schemaJSON?.arrangement.first)

        #expect(database.id == 71)
        #expect(database.title == "Orders")
        #expect(database.language == "postgresql")
        #expect(database.schema?.hasPrefix("CREATE TABLE") == true)
        #expect(table.name == "orders")
        #expect(table.columns.map(\.name) == ["id", "note"])
        #expect(table.columns.first?.pk == true)
        #expect(table.columns.last?.nn == false)
    }

    @Test
    func `custom database schema accepts arrangement wrapped in tables`() throws {
        let json = Data(
            #"""
            {
              "id": 10,
              "custom_database": {
                "id": 72,
                "schema_json": {
                  "arrangement": {
                    "tables": [{
                      "name": "users",
                      "columns": [{"name":"id","type":"INTEGER","pk":true,"nn":true}]
                    }]
                  }
                }
              }
            }
            """#.utf8
        )
        let question = try CoderPadClient.decoder.decode(Question.self, from: json)
        #expect(question.customDatabase?.schemaJSON?.arrangement.first?.name == "users")
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
