import Foundation

nonisolated extension MockScreenFixtures {
    /// Full UUID result entries; the list endpoint keeps its compact integer summaries.
    static func detailedQuestions() -> [[String: Any]] {
        let data = Data(detailedQuestionsJSON.utf8)
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }

    private static let detailedQuestionsJSON = #"""
    [
      {
        "id": "4143ca74-2f0e-4151-90d6-e1428739450b",
        "version": 4,
        "type": "PROJECT",
        "title": "Pagination",
        "domain": "API design",
        "warnings": [
          {
            "type": "CUSTOM_COMPANY_WARNING",
            "level": "UNUSUAL_ACTIVITY",
            "message": "Review activity"
          }
        ],
        "answer": {
          "project_answer": {
            "download_url": "/assessment/api/v1.1/tests/5001/questions/4143ca74-2f0e-4151-90d6-e1428739450b/project",
            "ai_assist_conversation_count": 0
          }
        },
        "evaluation": {
          "rubric": {
            "criteria": [
              {
                "label": "Clarity",
                "description": "Explain the API",
                "skill": "Communication",
                "outcome": "PENDING_MANUAL_REVIEW",
                "max_points": 10,
                "awarded_points": null,
                "result_message": "Review required",
                "result_overridden_by_recruiter": false,
                "review_mode": "AI_SUGGESTIONS",
                "ai_review": {
                  "rationale": "Insufficient context",
                  "no_recommendation_reason": "CONFIDENCE_SCORE_TOO_LOW"
                }
              },
              {
                "label": "Correctness",
                "outcome": "PASSED",
                "awarded_points": 5,
                "review_mode": "AI_GRADING",
                "ai_review": {
                  "recommended_outcome": "PASSED",
                  "rationale": "Correct"
                }
              }
            ]
          },
          "test_report": {
            "test_cases": [
              {
                "key": "page-one",
                "label": "First page",
                "skill": "API design",
                "outcome": "PASSED",
                "output": "ok\n",
                "test_identifier": "pagination.test#first",
                "max_points": 20,
                "awarded_points": 20,
                "result_overridden_by_recruiter": false
              },
              {
                "key": "boundary",
                "outcome": "NOT_RUN",
                "awarded_points": null
              }
            ]
          }
        },
        "max_points": 30,
        "awarded_points": 18,
        "time_limit_seconds": 1200,
        "time_spent_seconds": 1043,
        "first_access_time": 1685545371216,
        "submission_time": 1685545372216,
        "last_activity_time": 1685545373216,
        "answer_status": "ANSWERED",
        "grading_status": "PENDING_MANUAL_REVIEW",
        "timed_out": false,
        "result_overridden_by_recruiter": false,
        "marked_as_cheated_by_recruiter": false,
        "time_spent_outside_environment_seconds": 0,
        "environment_exit_count": 0
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e231",
        "type": "CODE",
        "answer": {
          "code_answer": {
            "code": "print(0)\r\n",
            "programming_language_id": "Python3"
          }
        },
        "evaluation": {
          "validation_code": {
            "test_cases": [
              {
                "label": "Boundary",
                "skill": "Collections",
                "outcome": "FAILED",
                "test_identifier": "testEmpty",
                "max_points": 20,
                "awarded_points": 0,
                "result_message": "Timeout",
                "result_overridden_by_recruiter": false,
                "timed_out": true
              }
            ]
          },
          "input_output": {
            "test_cases": [
              {
                "label": "Output",
                "skill": "Complexity",
                "outcome": "NOT_RUN",
                "max_points": 10,
                "awarded_points": null,
                "result_message": "Not run",
                "result_overridden_by_recruiter": false,
                "timed_out": false
              }
            ]
          },
          "sql_query_result_comparison": {
            "outcome": "PASSED",
            "max_points": 5,
            "awarded_points": 5,
            "result_message": "Rows match",
            "result_overridden_by_recruiter": true,
            "timed_out": false
          }
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "Code submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e232",
        "type": "GAME",
        "answer": {
          "game_answer": {
            "code": "move();\n"
          }
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "Game submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e233",
        "type": "TEXT",
        "answer": {
          "text_answer": {
            "text": "42"
          }
        },
        "evaluation": {
          "text_answer_matching": {
            "accepted_answers": [
              {
                "value": "42",
                "match_type": "EXACT"
              },
              {
                "value": "[0-9]+",
                "match_type": "REGEX"
              }
            ]
          }
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "Text submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e234",
        "type": "MCQ",
        "answer": {
          "mcq_answer": {
            "selected_choice_indexes": [
              2,
              0
            ]
          }
        },
        "evaluation": {
          "choice_selection": {
            "correct_choice_indexes": [
              0,
              2
            ]
          }
        },
        "mcq_details": {
          "choices": [
            {
              "label": "Linear"
            },
            {
              "label": "Quadratic"
            },
            {
              "label": "Constant"
            }
          ],
          "selection_mode": "MULTIPLE",
          "randomize_choices": false
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "Mcq submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e235",
        "type": "FILE_UPLOAD",
        "answer": {
          "file_upload_answer": {
            "filename": "architecture.pdf",
            "download_url": "https://example.com/file?signed=temporary",
            "candidate_comment": "Design"
          }
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "File_Upload submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e236",
        "type": "VIDEO",
        "answer": {
          "video_answer": {
            "recordings": [
              {
                "id": "0558b3e3-b76c-42ea-9435-8da1adb7e232",
                "url": "https://example.com/video",
                "transcript_url": "https://example.com/transcript",
                "duration_seconds": 187
              },
              {
                "id": "0558b3e3-b76c-42ea-9435-8da1adb7e233",
                "duration_seconds": 0
              }
            ],
            "recording_availability": "AVAILABLE",
            "candidate_comment": "Explanation"
          }
        },
        "max_points": 10,
        "awarded_points": 10,
        "title": "Video submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      },
      {
        "id": "0558b3e3-b76c-42ea-9435-8da1adb7e237",
        "type": "MULTI",
        "evaluation": {
          "rubric": {
            "criteria": []
          }
        },
        "warnings": [],
        "max_points": 10,
        "awarded_points": 10,
        "title": "Multi submission",
        "grading_status": "GRADED",
        "answer_status": "ANSWERED"
      }
    ]
    """#
}
