//
//  MockInterviewFidelityTests.swift
//  CoderPadKitTests
//
//  Regression coverage for Interview mock fidelity issues #117–#128: malformed
//  create/update bodies, contents/notes round-trip, unknown deletes, pad
//  environments, pagination/sort, question overlay leaks, multipart booleans,
//  and public-session bearer auth.
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Interview mock fidelity")
struct MockInterviewFidelityTests {
    private let client = CoderPadClient.mock(key: "interview-fidelity-\(UUID().uuidString)")

    // MARK: - #117 / #118 malformed pad bodies

    @Test(arguments: [
        Optional<Data>.none,
        Optional(Data()),
        Optional(Data("{".utf8)),
        Optional(Data("[]".utf8)),
        Optional(Data("\"x\"".utf8))
    ])
    func `malformed pad creates leave state unchanged and return 400`(body: Data?) async throws {
        let before = try await client.listPads().count
        let (status, _) = try await raw(
            method: "POST",
            path: "/api/pads/",
            body: body,
            contentType: "application/json"
        )
        #expect(status == 400)
        #expect(try await client.listPads().count == before)
    }

    @Test(arguments: [
        Optional<Data>.none,
        Optional(Data()),
        Optional(Data("{".utf8)),
        Optional(Data("[]".utf8))
    ])
    func `malformed pad updates return 400 without changing the pad`(body: Data?) async throws {
        let before = try await client.getPad(id: "DEMOABC1")
        let (status, _) = try await raw(
            method: "PUT",
            path: "/api/pads/DEMOABC1",
            body: body,
            contentType: "application/json"
        )
        #expect(status == 400)
        let after = try await client.getPad(id: "DEMOABC1")
        #expect(after.title == before.title)
        #expect(after.notes == before.notes)
    }

    // MARK: - #119 contents / notes on create

    @Test
    func `create pad round-trips contents and notes`() async throws {
        let created = try await client.createPad(
            PadCreate(title: "With body", contents: "print(1)", notes: "private note")
        )
        #expect(created.contents == "print(1)")
        #expect(created.notes == "private note")

        let fetched = try await client.getPad(id: created.id)
        #expect(fetched.contents == "print(1)")
        #expect(fetched.notes == "private note")
    }

    // MARK: - #120 unknown pad delete

    @Test
    func `deleting an unknown pad returns 404 without reserving the id`() async throws {
        let (status, _) = try await raw(
            method: "PUT",
            path: "/api/pads/NEVER-EXISTED",
            body: Data(#"{"deleted":true}"#.utf8),
            contentType: "application/json"
        )
        #expect(status == 404)

        // Creating a pad with a colliding id is impossible through the client, but a
        // subsequent create must still succeed and be listable (id not tombstoned).
        let created = try await client.createPad(PadCreate(title: "After unknown delete"))
        #expect(try await client.listPads().contains { $0.id == created.id })
    }

    // MARK: - #121 pad environments

    @Test
    func `unknown pad environment ids return 404`() async throws {
        await #expect(throws: CoderPadError.self) {
            _ = try await client.padEnvironment(id: 999_999)
        }
        // A seeded environment still resolves.
        let env = try await client.padEnvironment(id: 1)
        #expect(env.id == 1)
    }

    // MARK: - #122 pagination

    @Test
    func `question lists page at 50 with a next_page cursor`() async throws {
        let before = try await client.listQuestions().count
        let needed = max(0, 51 - before)
        for index in 0 ..< needed {
            _ = try await client.createQuestion(QuestionCreate(title: "Page filler \(index)"))
        }

        let (status, data) = try await raw(method: "GET", path: "/api/questions/")
        #expect(status == 200)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let page = try #require(json["questions"] as? [[String: Any]])
        #expect(page.count == 50)
        #expect(json["total"] as? Int == before + needed)
        let next = try #require(json["next_page"] as? String)
        #expect(next.contains("page=2"))
    }

    // MARK: - #123 sort

    @Test
    func `listPads honors created_at sort direction`() async throws {
        let asc = try await client.listPads(sort: "created_at,asc")
        let desc = try await client.listPads(sort: "created_at,desc")
        #expect(asc.map(\.id) == desc.map(\.id).reversed())
        #expect(asc.first?.id != desc.first?.id || asc.count <= 1)
    }

    @Test
    func `unsupported sort values return 400`() async throws {
        let (status, data) = try await raw(
            method: "GET",
            path: "/api/pads/",
            query: "sort=title,asc"
        )
        #expect(status == 400)
        #expect(String(decoding: data, as: UTF8.self).contains("invalid sort"))
    }

    // MARK: - #124 malformed question create

    @Test(arguments: [
        Optional<Data>.none,
        Optional(Data()),
        Optional(Data("{".utf8)),
        Optional(Data("[]".utf8))
    ])
    func `malformed question creates leave state unchanged`(body: Data?) async throws {
        let before = try await client.listQuestions().count
        let (status, _) = try await raw(
            method: "POST",
            path: "/api/questions/",
            body: body,
            contentType: "application/json"
        )
        #expect(status == 400)
        #expect(try await client.listQuestions().count == before)
    }

    // MARK: - #125 failed update leak

    @Test
    func `a failed question update does not leak into a later create`() async throws {
        let nextID = try await client.listQuestions().map(\.id).max().map { $0 + 1 } ?? 108
        let (status, _) = try await raw(
            method: "PUT",
            path: "/api/questions/\(nextID)",
            body: Data(#"{"question":{"title":"Leaked title"}}"#.utf8),
            contentType: "application/json"
        )
        #expect(status == 404)

        let created = try await client.createQuestion(QuestionCreate(title: "Fresh title"))
        #expect(created.id == nextID)
        #expect(created.title == "Fresh title")
        #expect(try await client.getQuestion(id: created.id).title == "Fresh title")
    }

    // MARK: - #126 unknown question delete

    @Test
    func `deleting an unknown question returns 404 and does not tombstone the next id`() async throws {
        let nextID = try await client.listQuestions().map(\.id).max().map { $0 + 1 } ?? 108
        let (status, _) = try await raw(method: "DELETE", path: "/api/questions/\(nextID)")
        #expect(status == 404)

        let created = try await client.createQuestion(QuestionCreate(title: "Survives"))
        #expect(created.id == nextID)
        #expect(try await client.getQuestion(id: created.id).title == "Survives")
    }

    // MARK: - #127 multipart true/false

    @Test
    func `multipart title true is preserved as a string`() async throws {
        let boundary = "bool-field-boundary"
        let body = Data(
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="question[title]"\r
            \r
            true\r
            --\(boundary)\r
            Content-Disposition: form-data; name="question[take_home]"\r
            \r
            true\r
            --\(boundary)--
            """.utf8
        )
        let (status, data) = try await raw(
            method: "POST",
            path: "/api/questions/",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        #expect(status == 200)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["title"] as? String == "true")
        #expect(json["take_home"] as? Bool == true)
    }

    // MARK: - #128 public session auth

    @Test(arguments: [
        Optional<String>.none,
        Optional(""),
        Optional("Token demo"),
        Optional("Bearer "),
        Optional("Bearer")
    ])
    func `public mock session rejects missing or malformed bearer tokens`(
        authorization: String?
    ) async throws {
        var request = URLRequest(url: URL(string: "https://app.coderpad.io/api/pads/")!)
        request.httpMethod = "GET"
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 401)
    }

    @Test
    func `public mock session accepts a nonempty bearer token`() async throws {
        var request = URLRequest(url: URL(string: "https://app.coderpad.io/api/pads/")!)
        request.httpMethod = "GET"
        request.setValue("Bearer demo-\(UUID().uuidString)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
    }

    // MARK: - Helpers

    private func raw(
        method: String,
        path: String,
        body: Data? = nil,
        contentType: String? = nil,
        query: String? = nil
    ) async throws -> (Int, Data) {
        var urlString = "https://app.coderpad.io\(path)"
        if let query { urlString += "?\(query)" }
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(client.apiKey)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await MockServer.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        return (http.statusCode, data)
    }
}
