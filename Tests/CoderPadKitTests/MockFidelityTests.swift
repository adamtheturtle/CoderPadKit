//
//  MockFidelityTests.swift
//  CoderPadKitTests
//
//  Regression tests for the write-then-read-back and mock-fidelity defects: a value
//  the package writes has to be readable again, and the fake API has to merge, mint
//  ids, and route URLs the way the live one does. Each test here fails without its
//  fix.
//

import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

/// Its own client (and so its own `MockState`) per test, like `MockServerTests`, so
/// the bulk-creation test can't perturb any other suite's counts.
@Suite("Mock server fidelity")
struct MockFidelityTests {
    private let client = CoderPadClient.mock(key: "fidelity-\(UUID().uuidString)")

    /// End-to-end companion to the `Pad` decode test: the value written through a real
    /// PUT has to survive the round trip. It travels as the string "false", so a strict
    /// `Bool` decode in `Pad` turned the flag the caller had just set into `nil`.
    @Test
    func `an execution_enabled edit reads back as the value that was written`() async throws {
        let before = try await client.getPad(id: "DEMOABC1")
        #expect(before.executionEnabled == true)

        let updated = try await client.updatePad(
            PadUpdate(id: "DEMOABC1", executionEnabled: false)
        )
        #expect(updated.executionEnabled == false)

        let reenabled = try await client.updatePad(
            PadUpdate(id: "DEMOABC1", executionEnabled: true)
        )
        #expect(reenabled.executionEnabled == true)
    }

    /// The live API applies a PUT as a partial update. `PadUpdate` encodes only its
    /// non-nil fields, so a second edit must not roll the first one back.
    @Test
    func `a second pad edit merges with the first rather than discarding it`() async throws {
        _ = try await client.updatePad(PadUpdate(id: "DEMOABC1", title: "Renamed"))
        let afterNotes = try await client.updatePad(PadUpdate(id: "DEMOABC1", notes: "Some notes"))

        #expect(afterNotes.title == "Renamed")
        #expect(afterNotes.notes == "Some notes")

        // A third edit of an unrelated field keeps both earlier ones.
        let afterLanguage = try await client.updatePad(PadUpdate(id: "DEMOABC1", language: "ruby"))
        #expect(afterLanguage.title == "Renamed")
        #expect(afterLanguage.notes == "Some notes")
        #expect(afterLanguage.language == "ruby")
    }

    /// `endPad` is the same PUT endpoint, so ending an interview must not revert the
    /// edits made during it.
    @Test
    func `ending a pad keeps the edits made before it`() async throws {
        _ = try await client.updatePad(PadUpdate(id: "DEMOABC1", title: "Renamed before ending"))
        try await client.endPad(id: "DEMOABC1")

        let ended = try await client.getPad(id: "DEMOABC1")
        #expect(ended.title == "Renamed before ending")
        #expect(ended.status == .ended)
    }

    @Test
    func `a second question edit merges with the first rather than discarding it`() async throws {
        _ = try await client.updateQuestion(QuestionUpdate(id: 101, title: "Renamed Q"))
        let afterDescription = try await client.updateQuestion(
            QuestionUpdate(id: 101, description: "New desc")
        )

        #expect(afterDescription.title == "Renamed Q")
        #expect(afterDescription.description == "New desc")
    }

    /// Every created question used to be minted id 108, because only the immutable
    /// seeds were consulted. The client de-duplicates by id, so the second creation
    /// returned a 200 and a `Question` for a record that never appeared in any listing.
    @Test
    func `each created question gets a distinct id and all of them stay listable`() async throws {
        let before = try await client.listQuestions()

        let first = try await client.createQuestion(QuestionCreate(title: "First new"))
        let second = try await client.createQuestion(QuestionCreate(title: "Second new"))
        let third = try await client.createQuestion(QuestionCreate(title: "Third new"))

        #expect(Set([first.id, second.id, third.id]).count == 3)
        #expect(!before.contains { $0.id == first.id })

        let after = try await client.listQuestions()
        #expect(after.count == before.count + 3)
        #expect(after.contains { $0.title == "First new" })
        #expect(after.contains { $0.title == "Second new" })
        #expect(after.contains { $0.title == "Third new" })

        // Each id resolves to the record that was actually created under it.
        #expect(try await client.getQuestion(id: second.id).title == "Second new")
        #expect(try await client.getQuestion(id: third.id).title == "Third new")
    }

    /// `createPad` drew a random id without checking it against the pads that already
    /// exist. A collision made the new pad vanish from `listPads()`, because the client
    /// de-duplicates by id. Enough creations that an unchecked draw is essentially
    /// certain to collide (~1e-24 chance of passing without the fix).
    @Test
    func `created pad ids never collide with pads that already exist`() async throws {
        let before = try await client.listPads()
        var minted: [String] = []
        for index in 0 ..< 1000 {
            minted.append(try await client.createPad(PadCreate(title: "Bulk \(index)")).id)
        }

        #expect(Set(minted).count == minted.count)
        #expect(Set(minted).isDisjoint(with: Set(before.map(\.id))))

        let after = try await client.listPads()
        #expect(after.count == before.count + minted.count)
    }

    /// The pad's own `history` field is the pad-level Firebase node the live API really
    /// hands out, so the mock has to route it. Previously only the per-file
    /// `PadEnvironmentFile.history` URLs resolved and a pad's own history 404ed.
    @Test
    func `a pad's own history URL resolves rather than 404ing`() async throws {
        let pad = try await client.getPad(id: "DEMOABC1")
        let historyURL = try #require(pad.history)
        #expect(historyURL.contains("/\(pad.id)/history.json"))

        let history = try await client.padHistory(historyURL: historyURL)
        #expect(!history.isEmpty)

        // It is the pad's active environment's buffer, so it replays to that content.
        let environment = try await client.padEnvironment(id: try #require(pad.activeEnvironmentID))
        #expect(history.replay() == environment.fileContents.first?.contents)
    }

    /// `interviewType` prefers `pad_type` over `take_home`, and every seeded and live
    /// question carries a `pad_type`, so an optimistic take-home flip that left
    /// `pad_type` alone was invisible to anything rendering from `interviewType`.
    @Test
    func `an optimistic take-home flip moves the derived interview type`() async throws {
        let question = try await client.getQuestion(id: 101)
        #expect(question.takeHome == false)
        #expect(question.interviewType == .live)

        let toTakeHome = question.applying(takeHome: true)
        #expect(toTakeHome.takeHome == true)
        #expect(toTakeHome.interviewType == .takeHome)

        // And back again.
        let backToLive = toTakeHome.applying(takeHome: false)
        #expect(backToLive.takeHome == false)
        #expect(backToLive.interviewType == .live)

        // An explicit `padType` still wins over the one derived from `takeHome`.
        let explicit = question.applying(takeHome: true, padType: "live")
        #expect(explicit.takeHome == true)
        #expect(explicit.interviewType == .live)

        // An edit that touches neither leaves the derived type alone.
        #expect(question.applying(title: "Renamed").interviewType == question.interviewType)
    }}
