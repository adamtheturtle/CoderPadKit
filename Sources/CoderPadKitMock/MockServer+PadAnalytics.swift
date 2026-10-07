import Foundation

extension MockFixtures {
    /// Detail-only analytics, with owner reports kept separate from shared transcripts.
    nonisolated static func padAnalytics(id: String, ownerEmail: String?) -> [String: Any] {
        var fields: [String: Any] = [:]
        if id == "DEMOXYZ2" {
            fields = [
                "interview_highlights": "The candidate explained pagination and boundary cases.",
                "interview_outline": [
                    "sections": [["title": "Boundary cases", "start_ms": 1_500]],
                    "completed": true
                ],
                "transcript": [
                    ["id": "transcript-1", "kind": "transcript", "speaker_name": "Mr Hamilton",
                     "speaker_role": "candidate", "text": "I would check an empty page.",
                     "timestamp": 1_780_680_000_000],
                    ["id": "transcript-2", "kind": "system_message", "speaker_name": NSNull(),
                     "speaker_role": NSNull(), "text": "Interview ended",
                     "timestamp": 1_780_680_002_000]
                ],
                "transcript_source_unavailable": false
            ]
        }
        if id == "DEMOSWFT5" {
            fields["transcript"] = [Any]()
            fields["transcript_source_unavailable"] = true
            if ownerEmail == demoUserEmail {
                fields["review_reports"] = [
                    ["id": "review-pending", "status": "pending", "title": "Code review",
                     "report": NSNull(), "file_paths": [String](), "created_at": "2026-06-10T08:00:00Z"],
                    ["id": "review-error", "status": "error", "error": "Review generation failed",
                     "report": NSNull(), "file_paths": ["src/main.swift"], "updated_at": "2026-06-10T08:02:00Z"]
                ]
            }
        }
        return fields
    }
}
