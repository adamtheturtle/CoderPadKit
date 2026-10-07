@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Detailed Screen results")
struct ScreenDetailedResultsTests {
    private func decode(_ payload: [String: Any]) throws -> ScreenTestSession {
        try JSONDecoder().decode(ScreenTestSession.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    private func fixture() throws -> ScreenTestSession {
        try decode(["id": 5001, "timer_type": "PER_QUESTION",
                    "questions": MockScreenFixtures.detailedQuestions()])
    }

    @Test
    func `UUID entries keep question order and submission formats`() throws {
        let result = try fixture()
        #expect(result.timerType == "PER_QUESTION")
        #expect(result.omittedQuestionCount == 0)
        #expect(result.questions == [])
        #expect(result.questionEntries.count == 8)
        let questions = result.detailedQuestions
        #expect(questions.map(\.type) == ["PROJECT", "CODE", "GAME", "TEXT", "MCQ", "FILE_UPLOAD", "VIDEO", "MULTI"])
        #expect(questions[0].id == UUID(uuidString: "4143ca74-2f0e-4151-90d6-e1428739450b"))
        #expect(questions[1].answer?.codeAnswer?.code == "print(0)\r\n")
        #expect(questions[1].answer?.codeAnswer?.programmingLanguageID == "Python3")
        #expect(questions[2].answer?.gameAnswer?.code == "move();\n")
        #expect(questions[3].answer?.textAnswer?.text == "42")
        #expect(questions[4].answer?.mcqAnswer?.selectedChoiceIndexes == [2, 0])
        #expect(questions[5].answer?.fileUploadAnswer?.filename == "architecture.pdf")
        #expect(questions[5].answer?.fileUploadAnswer?.downloadURL == "https://example.com/file?signed=temporary")
        #expect(questions[5].answer?.fileUploadAnswer?.candidateComment == "Design")
        #expect(questions[6].answer?.videoAnswer?.recordingAvailability == "AVAILABLE")
        #expect(questions[6].answer?.videoAnswer?.recordings?.map(\.durationSeconds) == [187, 0])
        #expect(questions[6].answer?.videoAnswer?.recordings?.first?.transcriptURL == "https://example.com/transcript")
        #expect(questions[7].answer == nil)
        #expect(questions[7].warnings == [])
        #expect(questions[7].evaluation?.rubric?.criteria == [])
    }

    @Test
    func `project grading retains pending points ordered criteria and AI reasons`() throws {
        let question = try #require(try fixture().detailedQuestions.first)
        #expect(question.warnings?.map(\.type) == ["CUSTOM_COMPANY_WARNING"])
        #expect(question.warnings?.first?.level == "UNUSUAL_ACTIVITY")
        #expect(question.warnings?.first?.message == "Review activity")
        #expect(question.gradingStatus == "PENDING_MANUAL_REVIEW")
        #expect(question.answerStatus == "ANSWERED")
        #expect(question.timeLimitSeconds == 1200)
        #expect(question.timeSpentSeconds == 1043)
        #expect(question.firstAccessTime == 1_685_545_371_216)
        #expect(question.submissionTime == 1_685_545_372_216)
        #expect(question.lastActivityTime == 1_685_545_373_216)
        #expect(question.timedOut == false)
        #expect(question.resultOverriddenByRecruiter == false)
        #expect(question.markedAsCheatedByRecruiter == false)
        #expect(question.timeSpentOutsideEnvironmentSeconds == 0)
        #expect(question.environmentExitCount == 0)
        #expect(question.answer?.projectAnswer?.aiAssistConversationCount == 0)
        #expect(question.answer?.projectAnswer?.downloadURL
            == "/assessment/api/v1.1/tests/5001/questions/4143ca74-2f0e-4151-90d6-e1428739450b/project")
        let criteria = try #require(question.evaluation?.rubric?.criteria)
        #expect(criteria.map(\.label) == ["Clarity", "Correctness"])
        #expect(criteria.map(\.awardedPoints) == [nil, 5])
        #expect(criteria[0].resultOverriddenByRecruiter == false)
        #expect(criteria[0].reviewMode == "AI_SUGGESTIONS")
        #expect(criteria[0].aiReview?.recommendedOutcome == nil)
        #expect(criteria[0].aiReview?.noRecommendationReason == "CONFIDENCE_SCORE_TOO_LOW")
        #expect(criteria[1].aiReview?.recommendedOutcome == "PASSED")
        let cases = try #require(question.evaluation?.testReport?.testCases)
        #expect(cases.map(\.key) == ["page-one", "boundary"])
        #expect(cases.map(\.awardedPoints) == [20, nil])
        #expect(cases[0].output == "ok\n")
        #expect(cases[0].testIdentifier == "pagination.test#first")
    }

    @Test
    func `all evaluation methods and MCQ choice metadata survive`() throws {
        let questions = try fixture().detailedQuestions
        let evaluation = try #require(questions[1].evaluation)
        let validation = try #require(evaluation.validationCode?.testCases?.first)
        #expect(validation.testIdentifier == "testEmpty")
        #expect(validation.awardedPoints == 0)
        #expect(validation.timedOut == true)
        #expect(validation.resultOverriddenByRecruiter == false)
        #expect(evaluation.inputOutput?.testCases?.first?.awardedPoints == nil)
        #expect(evaluation.inputOutput?.testCases?.first?.timedOut == false)
        #expect(evaluation.sqlQueryResultComparison?.awardedPoints == 5)
        #expect(evaluation.sqlQueryResultComparison?.resultOverriddenByRecruiter == true)
        #expect(questions[3].evaluation?.textAnswerMatching?.acceptedAnswers?.map(\.matchType) == ["EXACT", "REGEX"])
        #expect(questions[4].evaluation?.choiceSelection?.correctChoiceIndexes == [0, 2])
        #expect(questions[4].mcqDetails?.choices?.map(\.label) == ["Linear", "Quadratic", "Constant"])
        #expect(questions[4].mcqDetails?.selectionMode == "MULTIPLE")
        #expect(questions[4].mcqDetails?.randomizeChoices == false)
    }

    @Test(arguments: ["GLOBAL", "UNLIMITED", "PER_QUESTION", "FUTURE_TIMER"])
    func `unfinished entries keep optional answers and future timer values`(timer: String) throws {
        let result = try decode(["id": 1, "timer_type": timer, "questions": [[
            "id": "4143ca74-2f0e-4151-90d6-e1428739450b", "grading_status": "FUTURE_STATUS"
        ]]])
        let question = try #require(result.detailedQuestions.first)
        #expect(result.timerType == timer)
        #expect(question.gradingStatus == "FUTURE_STATUS")
        #expect(question.answer == nil)
        #expect(question.evaluation == nil)
        #expect(question.awardedPoints == nil)
        #expect(question.warnings == nil)
        #expect(question.markedAsCheatedByRecruiter == nil)
        #expect(question.timeLimitSeconds == nil)
    }

    @Test
    func `mixed identities preserve order while malformed entries are counted`() throws {
        let result = try decode(["id": 1, "questions": [
            ["id": 123, "last_activity_time": 1_685_545_371_216],
            ["id": "4143ca74-2f0e-4151-90d6-e1428739450b", "type": "FUTURE_TYPE"],
            ["id": "invalid"], ["id": "0558b3e3-b76c-42ea-9435-8da1adb7e232", "awarded_points": "0"]
        ]])
        #expect(result.questionEntries.count == 2)
        #expect(result.omittedQuestionCount == 2)
        #expect(result.questions.map(\.id) == [123])
        #expect(result.questions.first?.lastActivityTime == 1_685_545_371_216)
        #expect(result.detailedQuestions.map(\.type) == ["FUTURE_TYPE"])
        guard case .summary = result.questionEntries[0], case .detailed = result.questionEntries[1] else {
            Issue.record("Original identity order changed")
            return
        }
    }

    @Test
    func `restricted reports and unavailable recordings remain valid`() throws {
        for payload: [String: Any] in [["id": 1], ["id": 1, "questions": NSNull()], ["id": 1, "questions": []]] {
            let result = try decode(payload)
            #expect(result.questionEntries == [])
            #expect(result.omittedQuestionCount == 0)
            #expect(result.timerType == nil)
        }
        let result = try decode(["id": 1, "questions": [[
            "id": "4143ca74-2f0e-4151-90d6-e1428739450b",
            "new_field": true, "answer": ["video_answer": ["recording_availability": "UNAVAILABLE"]]
        ]]])
        #expect(result.detailedQuestions.first?.answer?.videoAnswer?.recordings == nil)
        #expect(result.detailedQuestions.first?.answer?.videoAnswer?.recordingAvailability == "UNAVAILABLE")
    }

    @Test
    func `demo list stays compact and detail exposes UUID results and report activity`() async throws {
        let client = ScreenClient.mock(key: "detailed-\(UUID().uuidString)")
        let page = try await client.listTests(limit: 50)
        let summary = try #require(page.tests.first { $0.id == 5001 })
        #expect(summary.questions.isEmpty == false)
        #expect(summary.detailedQuestions == [])
        let result = try await client.getTest(id: 5001)
        #expect(result.detailedQuestions.count == 8)
        #expect(result.omittedQuestionCount == 0)
        #expect(result.timerType == "GLOBAL")
        #expect(result.report?.markedAsCheatedByRecruiter == false)
        #expect(result.report?.timeSpentOutsideEnvironmentSeconds == 0)
        #expect(result.report?.environmentExitCount == 0)
        #expect(try await client.getTest(id: 5002).questionEntries == [])
    }
}
