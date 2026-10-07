@testable import CoderPadKit
@testable import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen question insights")
struct ScreenQuestionInsightsTests {
    @Test(arguments: [nil, "C++"] as [String?])
    func `usage and frequency statistics retain zero and false values`(language: String?) async throws {
        let id = try #require(UUID(uuidString: MockScreenFixtures.insightsQuestionID))
        let result = try await ScreenClient.mock().questionInsights(id: id, programmingLanguage: language)
        #expect(result.id == id.uuidString.lowercased())
        #expect(result.usage?.viewCount == 12)
        #expect(result.usage?.lastViewTime == "2026-10-01T00:00:00Z")
        #expect(result.usage?.averageAnswerDurationSeconds == 0)
        #expect(result.usage?.timeoutRate == 0)
        #expect(result.usage?.averageScore == (language == "C++" ? 0.5 : 0))
        #expect(result.frequentAnswers?.first?.label == "A")
        #expect(result.frequentAnswers?.first?.count == 0)
        #expect(result.frequentAnswers?.first?.percentage == 0)
        #expect(result.frequentAnswers?.first?.correct == false)
        #expect(result.testcasesSuccess?.first?.label == "Case 1")
        #expect(result.testcasesSuccess?.first?.count == 2)
        #expect(result.testcasesSuccess?.first?.percentage == 1)
        #expect(result.testcasesSuccess?.first?.correct == true)
        #expect(result.scoresDistribution?.distribution?.map(\.scoreRange)
            == ["ZERO_SCORE", "PARTIAL_SCORE", "FULL_SCORE"])
        #expect(result.scoresDistribution?.distribution?.map(\.candidateCount) == [0, 1, 2])
        #expect(result.scoresDistribution?.totalCandidates == 3)
    }

    @Test
    func `empty and unavailable insights remain distinct`() async throws {
        let id = try #require(UUID(uuidString: MockScreenFixtures.emptyInsightsQuestionID))
        let result = try await ScreenClient.mock().questionInsights(id: id)
        #expect(result.usage == nil)
        #expect(result.frequentAnswers == [])
        #expect(result.testcasesSuccess == [])
        #expect(result.scoresDistribution?.distribution == [])
        #expect(result.scoresDistribution?.totalCandidates == 0)
        let missing = try JSONDecoder().decode(ScreenQuestionInsights.self, from: Data("{}".utf8))
        #expect(missing.id == nil)
        #expect(missing.usage == nil)
        #expect(missing.frequentAnswers == nil)
        #expect(missing.testcasesSuccess == nil)
        #expect(missing.scoresDistribution == nil)
    }

    @Test
    func `partial responses keep available values and ignore future metadata`() throws {
        let input = Data(#"""
        {"usage":{"view_count":0,"extra":"new"},"frequent_answers":[{"correct":false}],
        "scores_distribution":{"distribution":[{"score_range":"FUTURE_BUCKET"}]},"new_field":123}
        """#.utf8)
        let result = try JSONDecoder().decode(ScreenQuestionInsights.self, from: input)
        #expect(result.usage?.viewCount == 0)
        #expect(result.usage?.averageScore == nil)
        #expect(result.frequentAnswers?.first?.correct == false)
        #expect(result.frequentAnswers?.first?.label == nil)
        #expect(result.scoresDistribution?.distribution?.first?.scoreRange == "FUTURE_BUCKET")
        #expect(result.scoresDistribution?.totalCandidates == nil)
    }

    @Test(arguments: [400, 404])
    func `invalid language and unknown question preserve HTTP errors`(status: Int) async throws {
        let id = status == 400 ? try #require(UUID(uuidString: MockScreenFixtures.insightsQuestionID)) : UUID()
        do {
            _ = try await ScreenClient.mock().questionInsights(id: id,
                                                               programmingLanguage: status == 400 ? "invalid" : nil)
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case let .http(code, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == status)
        }
    }

    @Test
    func `missing and unauthorized credentials use existing errors`() async throws {
        do {
            _ = try await ScreenClient(apiKey: "").questionInsights(id: UUID())
            Issue.record("Expected a missing-key error")
        } catch let error as CoderPadError {
            guard case .missingAPIKey = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
        do {
            _ = try await ScreenClient.mock(unauthorized: true).questionInsights(id: UUID())
            Issue.record("Expected an HTTP error")
        } catch let error as CoderPadError {
            guard case .http(401, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }
}
