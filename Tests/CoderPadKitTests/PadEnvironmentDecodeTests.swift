//
//  PadEnvironmentDecodeTests.swift
//  CoderPadKitTests
//
//  Pad environment and remaining question decode tolerance.
//

import CoderPadKit
import Foundation
import Testing

@Suite("Pad environment decode tolerance")
struct PadEnvironmentDecodeTests {
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
        #expect(environment.omittedFileCount == 0)
        #expect(environment.omittedFilesDiagnostic == nil)
    }

    @Test
    func `environment keeps valid files when one sibling is malformed`() throws {
        let json = Data(
            #"""
            {
              "id": 8,
              "file_contents": [
                {"path":"main.py","contents":"print(1)"},
                "not-a-file",
                {"path":"helper.py","contents":"print(2)","binary":"nope"},
                {"path":"ok.py","contents":"print(3)"}
              ]
            }
            """#.utf8
        )
        let environment = try CoderPadClient.decoder.decode(PadEnvironment.self, from: json)

        #expect(environment.fileContents.map(\.path) == ["main.py", "ok.py"])
        #expect(environment.omittedFileCount == 2)
        #expect(environment.omittedFilesDiagnostic == "Ignored 2 malformed environment files.")
    }

    @Test
    func `Question decodes present null and absent AI Assist custom system prompts`() throws {
        for (fragment, expected): (String, String?) in [
            (#","ai_assist_custom_system_prompt":"  Keep this spacing.  ""#, "  Keep this spacing.  "),
            (#","ai_assist_custom_system_prompt":null"#, nil),
            ("", nil)
        ] {
            let json = Data(#"{"id":9\#(fragment)}"#.utf8)
            let question = try CoderPadClient.decoder.decode(Question.self, from: json)
            #expect(question.aiAssistCustomSystemPrompt == expected)
        }
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
