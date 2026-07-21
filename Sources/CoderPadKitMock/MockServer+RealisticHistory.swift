//
//  MockServer+RealisticHistory.swift
//  CoderPadKit
//
//  Deterministic, replayable editor traffic for the fake API. The fixture is
//  intentionally substantial enough to exercise timeline density and playback
//  performance, rather than representing a completed file as one giant paste.
//

import Foundation

nonisolated extension MockFixtures {
    static func realisticHistory(
        contents: String, start: Int64, seedAuthor: String
    ) -> [String: Any] {
        let characters = contents.map(String.init)
        let seedCount = min(24, max(1, characters.count / 12))
        let seed = characters.prefix(seedCount).joined()
        var offset = seed.utf16.count
        var timestamp = start
        var result: [String: Any] = [
            "0000-seed": ["a": seedAuthor, "o": [seed], "t": timestamp]
        ]

        // A candidate joins after the interviewer has introduced the exercise.
        // Per-character entries model normal collaborative-editor OT traffic;
        // deterministic cadence changes and pauses make playback feel human.
        timestamp += 1_204_000
        for (index, character) in characters.dropFirst(seedCount).enumerated() {
            let sequence = index + 1
            result[key(sequence, "type")] = [
                "a": "4503601411610331", "o": [offset, character], "t": timestamp
            ]
            offset += character.utf16.count
            timestamp += typingDelay(after: character, sequence: sequence)

            // Occasional corrected slips exercise deletes without changing the
            // final environment contents. These are separate events, as emitted
            // by a real editor, rather than a synthetic insert/delete compound.
            if sequence.isMultiple(of: 73) {
                result[key(sequence, "typo")] = [
                    "a": "4503601411610331", "o": [offset, "x"], "t": timestamp
                ]
                timestamp += 180
                result[key(sequence, "backspace")] = [
                    "a": "4503601411610331", "o": [offset, -1], "t": timestamp
                ]
                timestamp += 95
            }
        }

        // A late interviewer review jumps to the top of the document, briefly
        // inserts feedback, and removes it. The same-millisecond final pair also
        // exercises the Firebase decoder's deterministic id tie-break ordering.
        let review = "# Consider the empty-input case\n"
        let reviewTime = start + 2_515_000
        result["9000-review-insert"] = [
            "a": "9988776655443322", "o": [review], "t": reviewTime - 15_000
        ]
        result["9001-review-delete"] = [
            "a": "9988776655443322", "o": [-review.utf16.count], "t": reviewTime - 9_000
        ]
        result["9998-trailing-space"] = [
            "a": "9988776655443322", "o": [offset, " "], "t": reviewTime
        ]
        result["9999-trailing-space-delete"] = [
            "a": "9988776655443322", "o": [offset, -1], "t": reviewTime
        ]
        return result
    }

    private static func key(_ sequence: Int, _ action: String) -> String {
        String(format: "%04d-%@", sequence, action)
    }

    private static func typingDelay(after character: String, sequence: Int) -> Int64 {
        if character == "\n" { return sequence.isMultiple(of: 11) ? 7_500 : 650 }
        if character == " " { return 45 }
        if ",.:()[]{}".contains(character) { return 140 }
        return Int64(65 + sequence % 5 * 23)
    }
}
