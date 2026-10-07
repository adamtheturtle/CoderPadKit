@testable import CoderPadKit
import CoderPadKitMock
import Foundation
import Testing

@Suite("Screen code question payloads")
struct ScreenQuestionCodePayloadTests {
    @Test
    func `code authoring keeps nested grading and function signature metadata`() async throws {
        let input = ScreenQuestionSave(type: .code,
            evaluation: ScreenEvaluationInput(
                validationCode: ScreenValidationCodeInput(testCases: [ScreenValidationCodeTestCaseInput(
                    label: ["en": "Empty"], testIdentifier: "testEmpty", points: 0,
                    contributesToScore: false, visibleToCandidate: false
                )]),
                inputOutput: ScreenInputOutputEvaluationInput(testCases: [ScreenInputOutputTestCaseInput(
                    label: ["en": "Output"], input: "0", output: "0",
                    timeoutMSByProgrammingLanguageID: ["Python3": 5000]
                )]),
                sqlQueryResultComparison: ScreenSQLQueryResultComparisonInput(
                    referenceQuery: "SELECT 1", comparison: ScreenQueryComparisonRulesInput(
                        rowOrderMatters: false, columnOrderMatters: true, compareAllTables: false
                    )
                )
            ),
            codeDetails: ScreenCodeInput(
                environment: ScreenEnvironmentInput(version: "1", environmentID: "python"), mode: .singleLanguage,
                programmingLanguageID: "Python3", candidateTestCode: "solve()", validatorCode: "validate()",
                timeoutMS: 0,
                databaseEngine: ScreenDatabaseEngineInput(version: "16", engineID: "postgresql"),
                databaseSetupScript: "CREATE TABLE example (id int)", starterCode: "",
                functionSignature: ScreenFunctionSignatureInput(name: "solve", parameters: [
                    ["name": .string("items"), "type": .object(["kind": .string("array"), "element": .string("int")])]
                ], returnType: ["kind": .string("int")]),
                possibleSolution: ScreenPossibleSolutionInput(code: "return 42", programmingLanguageID: "Python3"),
                showFunctionSignatureInStatement: false
            )
        )
        let expected = Data(#"""
        {"type":"CODE","evaluation":{
          "validation_code":{"test_cases":[{"label":{"en":"Empty"},"test_identifier":"testEmpty","points":0,
          "contributes_to_score":false,"visible_to_candidate":false}]},
          "input_output":{"test_cases":[{"label":{"en":"Output"},"input":"0","output":"0",
          "timeout_ms_by_programming_language_id":{"Python3":5000}}]},
          "sql_query_result_comparison":{"reference_query":"SELECT 1","comparison":{"row_order_matters":false,
          "column_order_matters":true,"compare_all_tables":false}}},
          "code_details":{"environment":{"version":"1","environment_id":"python"},"mode":"SINGLE_LANGUAGE",
          "programming_language_id":"Python3","candidate_test_code":"solve()","validator_code":"validate()",
          "timeout_ms":0,"database_engine":{"version":"16","engine_id":"postgresql"},
          "database_setup_script":"CREATE TABLE example (id int)","starter_code":"",
          "function_signature":{"name":"solve","parameters":[{"name":"items","type":{"kind":"array",
          "element":"int"}}],"return_type":{"kind":"int"}},
          "possible_solution":{"code":"return 42","programming_language_id":"Python3"},
          "show_function_signature_in_statement":false}}
        """#.utf8)
        #expect(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(input))
            == JSONDecoder().decode(JSONValue.self, from: expected))
        let result = try await ScreenClient.mock(key: "code-save-\(UUID().uuidString)").createQuestion(input)
        #expect(result.question.codeDetails?.starterCode == "")
        #expect(result.question.codeDetails?.timeoutMS == 0)
        #expect(result.question.codeDetails?.showFunctionSignatureInStatement == false)
        #expect(result.question.codeDetails?.functionSignature?.returnType == ["kind": .string("int")])
        #expect(result.question.evaluation?.validationCode?.testCases?.first?.points == 0)
        #expect(result.question.evaluation?.validationCode?.testCases?.first?.contributesToScore == false)
        #expect(result.question.evaluation?.inputOutput?.testCases?.first?.timeoutMSByProgrammingLanguageID
            == ["Python3": 5000])
        #expect(result.question.evaluation?.sqlQueryResultComparison?.comparison?.columnOrderMatters == true)
    }
}
