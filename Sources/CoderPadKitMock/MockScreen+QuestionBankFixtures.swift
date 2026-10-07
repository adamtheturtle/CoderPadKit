import Foundation

nonisolated extension MockScreenFixtures {
    static let projectBankQuestionID = "4143ca74-2f0e-4151-90d6-e1428739450b"

    static func questionBank() -> [[String: Any]] {
        ["PROJECT", "CODE", "MCQ", "TEXT", "VIDEO", "GAME", "FILE_UPLOAD", "MULTI", "CLASH", "COURSE"]
            .enumerated().map { index, type in
                let tail = String(format: "%012x", index + 11)
                var question: [String: Any] = [
                    "id": "4143ca74-2f0e-4151-90d6-" + tail, "version": 1, "type": type,
                    "title": ["en": "Demo \(type)"], "statement": ["en": "Synthetic assessment content"],
                    "domain": "Backend", "skill": "Problem solving", "difficulty": "EASY", "product": "SCREEN",
                    "duration_seconds": index * 60, "programming_language_id": "C++",
                    "from_coderpad_question_bank": index > 4, "points": 0, "automatically_selectable": false
                ]
                if index == 0 { question["id"] = projectBankQuestionID }
                switch type {
                case "PROJECT":
                    question["project_details"] = ["environment": ["environment_id": "python", "version": "1"],
                        "resources": [], "ai_assist_allowed": false,
                        "download_url": "https://example.com/project.tar.gz"]
                    question["evaluation"] = ["test_report": ["test_cases": [["key": "case-1", "points": 0]]]]
                case "CODE": question["code_details"] = ["starter_code": "", "programming_language_id": "cpp"]
                case "MCQ": question["mcq_details"] = ["choices": [], "randomize_choices": false]
                case "TEXT": question["text_details"] = ["evaluation_mode": "MANUAL"]
                case "VIDEO": question["video_details"] = ["recording_media": "VIDEO"]
                case "GAME": question["game_details"] = ["available_programming_language_ids": []]
                case "FILE_UPLOAD": question["file_upload_details"] = ["download_url": "https://example.com/answer"]
                default: break
                }
                return question
            }
    }
}
