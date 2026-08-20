//
//  QuestionInstructionSchemaDecodeTests.swift
//  CoderPadKitTests
//

import CoderPadKit
import Foundation
import Testing

@Suite("Question instruction and schema decode")
struct QuestionInstructionSchemaDecodeTests {
    @Test
    func `CandidateInstruction tolerates absent fields`() throws {
        let decoded = try CoderPadClient.decoder.decode(
            CandidateInstruction.self, from: Data(#"{}"#.utf8)
        )
        #expect(decoded.instructions.isEmpty)
        #expect(decoded.defaultVisible)
    }

    @Test
    func `CandidateInstruction tolerates explicit nulls`() throws {
        let decoded = try CoderPadClient.decoder.decode(
            CandidateInstruction.self,
            from: Data(#"{"instructions":null,"default_visible":null}"#.utf8)
        )
        #expect(decoded.instructions.isEmpty)
        #expect(decoded.defaultVisible)
    }

    @Test(arguments: [
        #"{"instructions":1}"#,
        #"{"default_visible":"yes"}"#,
        #"{"instructions":{"text":"x"}}"#
    ])
    func `CandidateInstruction rejects wrong-typed fields`(json: String) {
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(CandidateInstruction.self, from: Data(json.utf8))
        }
    }

    @Test
    func `malformed arrangement does not become an empty schema`() {
        let json = Data(
            #"""
            {
              "arrangement": {"tables": "not-an-array"}
            }
            """#.utf8
        )
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(QuestionCustomDatabaseSchema.self, from: json)
        }
    }

    @Test
    func `present but invalid arrangement is rejected even when tables is usable`() {
        let json = Data(
            #"""
            {
              "arrangement": 12,
              "tables": [{"name":"users","columns":[{"name":"id","type":"INTEGER","pk":true,"nn":true}]}]
            }
            """#.utf8
        )
        #expect(throws: DecodingError.self) {
            try CoderPadClient.decoder.decode(QuestionCustomDatabaseSchema.self, from: json)
        }
    }

    @Test
    func `absent arrangement yields an empty schema`() throws {
        let schema = try CoderPadClient.decoder.decode(
            QuestionCustomDatabaseSchema.self, from: Data(#"{}"#.utf8)
        )
        #expect(schema.arrangement.isEmpty)
    }
}
