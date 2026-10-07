# CoderPadKit

An unofficial Swift client for the CoderPad REST API, with typed models and a no-network mock backend.

[Documentation](https://swiftpackageindex.com/adamtheturtle/CoderPadKit/documentation/coderpadkit) | [Swift Package Index](https://swiftpackageindex.com/adamtheturtle/CoderPadKit) | [Release notes](CHANGELOG.md)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/CoderPadKit.git", from: "0.1.3")
```

Add `CoderPadKit` to your app target and `CoderPadKitMock` to tests or demos that should run without the network.

## Multi-file questions

Create or replace a multi-file question's starter files with typed path/content values:

```swift
let request = QuestionCreate(
    title: "Service exercise",
    language: "multifile_python",
    fileContents: [
        QuestionFileContent(path: "main.py", contents: "from service import run\n"),
        QuestionFileContent(path: "service.py", contents: "def run():\n    return 'ready'\n")
    ]
)
let question = try await client.createQuestion(request)
```

`fileContents` is mutually exclusive with the legacy single-file `contents` property and ZIP uploads; conflicting requests fail locally before networking.

## Products

- `CoderPadKit`: Typed API client for pads (including editor-history replay), questions, organizations, and quota data.
- `CoderPadKitMock`: In-process fake API seeded with canned data.

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+

## License

MIT.
See [LICENSE](LICENSE).

Question library filters
------------------------

`listQuestions` and `listQuestionsIncrementally` accept `text` and `padTypes` (`.any`, `.live`, or `.takeHome`).
Organization question methods accept `padType` and `language`, including an incremental method.
Each page keeps these filters.
`InterviewQuestionSort` adds title and usage sorting in either direction.
Pass its `rawValue` as `sort`.
Omit sorting to retain API defaults.
Pad and event sorting continues to use `InterviewListSort`.

## Pad controls

`PadCreate` and `PadUpdate` accept `restrictInterviewerAccess`, `allowedInterviewerEmails`, and `disableCoachingTips` alongside existing ownership, privacy, and execution options.
Omit the email list to retain existing access, or pass `[]` to clear it.
Explicit `false` values are sent, and execution remains encoded as the string `"true"` or `"false"`.

Only `PadCreate` accepts `takeHome`, `takeHomeTimeLimit` (minutes), and `aiAssistEnabled`.
Omit them to inherit question and organization defaults.
`Pad.allowedInterviewerEmails` retains response metadata and survives optimistic inline edits.
The mock backend supports the same list replacement semantics.

### Interview analytics

`getPad(id:)` retains optional `interviewHighlights`, `interviewOutline`, `transcript`, `transcriptSourceUnavailable`, and `reviewReports`.
Highlights, outlines, and transcripts require Insights & Analytics, and review reports are returned only to the pad owner.
Ordinary pad and list responses can omit all of these fields.
An absent transcript is `nil`, an explicitly empty transcript is `[]`, and the unavailable-source flag remains independent.

`TranscriptEntry` retains spoken and system-message kinds, optional speaker metadata, text, and timestamps in epoch milliseconds.
`ReviewReport` retains open status strings, optional report and error content, file paths, reviewer identity, and creation/update dates. Pending and failed reviews stay available even when their report text is absent. The outline uses `JSONValue` to preserve arbitrary objects, arrays, strings, decimal numbers, Boolean values, and nulls. Optimistic pad edits preserve all analytics metadata. The mock API includes spoken transcripts, unavailable sources, and owner-only pending/error reviews on detail routes.

### Question sharing and database selection

`QuestionCreate` and `QuestionUpdate` accept optional `shared` and `customDatabaseID` fields.
Omitted sharing keeps the server default or existing value, while explicit `false` and `true` are sent unchanged.
Only the question author can change sharing, and permission failures use the existing API error contract.
Database identity is encoded as an integer in JSON and as decimal text in multipart requests.
These options work with ordinary question content and ZIP uploads while retaining the existing content-source rules.
The mock API supports the seeded database identity 501 and rejects unknown identities.
