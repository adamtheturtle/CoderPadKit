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

Create Screen campaigns with `createCampaign(ScreenCampaignCreation(name:questions:settings:teamID:))`.
Use ordered `ScreenCampaignQuestion.question(UUID)` and `.randomQuestionSet(ScreenRandomQuestionConfiguration(...))` entries.
Random inclusion and exclusion lists are mutually exclusive.
`ScreenCampaignSettings` supports languages, timer, invitation expiry, ISO 8601 access windows, follow-up questions, webcam analysis, AI Assist, and coding agents.
Omitted settings inherit team defaults, while false, zero, and empty values are sent explicitly.
`enabledCodingAgents` is a string, and an empty string disables agents.
Creation returns `ScreenCreatedCampaign.id`, makes one request, and surfaces feature restrictions through the usual HTTP error contract.

### Parent-question project files

`Question.fileContents` exposes starter files with path, optional text, hidden, and deleted metadata.
`Question.questionVariants` contains compact `QuestionVariantSummary` values, including nullable language, project template identity/slug, and display name.
These summaries require neither full variant code nor timestamps.
Starter files are separate from the downloadable attachments in `customFiles`.

`QuestionFileContent(path:contents:hidden:deleted:)` supports hidden files and path-only template deletion entries.
Text remains required when `deleted` is not true, and `.cpad` cannot be deleted.
Structured files overlay template files during creation, including an empty overlay retaining defaults.
ZIP uploads replace template files except for preserved `.cpad`.
Deleted entries on parent-question updates are ignored by the service.
Optimistic edits preserve starter files and variant summaries.

Use `ScreenClient.questionInsights(id:programmingLanguage:)` to retrieve statistics for a UUID question, optionally filtered by programming language.
`ScreenQuestionInsights` retains usage counts and timestamps, average elapsed time, timeout and score ratios, answer frequencies, test-case success, score buckets, and total candidates.
Unavailable fields remain nil, while explicit empty lists, false values, and zero metrics remain available.
The usual HTTP error contract applies to invalid languages and missing questions.

Use `ScreenClient.uploadTemporaryFile(_:)` with the original gzip archive `Data` to obtain a `ScreenTemporaryFile.id`.
The client sends `application/gzip` and the exact `Content-Length`, and rejects bodies larger than 52,428,800 bytes before networking.
Use the temporary ID promptly in `project_details.temporary_file_id` when creating a project question.
Unused uploads are eventually deleted by the service.
The usual error contract applies to permission and upload failures, and uploads are never automatically retried.
The client's configured timeout and normal task cancellation apply.

Use `ScreenClient.aiAssistConversations(testID:questionID:)` with an integer test ID and UUID project question ID.
Conversations retain their identity, subject, original ISO 8601 timestamps, and ordered messages with USER/ASSISTANT roles.
Message `outputItems` preserves structured JSON, including unknown fields, reasoning, tool calls, and text chunks.
Missing output stays nil and explicitly empty output stays empty.
Conversations are available after completion or while awaiting manual review.
Missing project questions return HTTP 404 and unfinished sessions return HTTP 409 through the existing error contract.

### Screen question library

`ScreenClient.listQuestions(filters:start:limit:)` returns `ScreenQuestionsPage` summaries with UUID identities.
`listAllQuestions(filters:start:limit:)` preserves filters across advancing offsets and applies the existing full-list page and item bounds.
`ScreenQuestionFilters` supports type, duration bounds, difficulty, domain, skill, programming language, library origin, product, and separate sort/order values.
False and zero filters remain explicit, and literal plus signs are encoded in query values.

`getQuestion(id:)` returns full `ScreenQuestionDetails`, including localized content, version, resources, type-specific settings, and evaluation metadata.
Read models support CODE, MCQ, TEXT, GAME, FILE_UPLOAD, PROJECT, VIDEO, and legacy MULTI/CLASH/COURSE content.
Unavailable fields remain nil and empty collections remain empty.

`createQuestion(_:)` accepts `ScreenQuestionSave` and returns `ScreenCreatedQuestion` with question details and an optional Location header.
`updateQuestion(id:_:)` sends PUT and returns updated details.
Save models accept the six writable question types and separate writable evaluation options from server-owned `test_report` data and download URLs.
Project creation accepts `ScreenProjectInput.temporaryFileID`, while archive replacement on updates requires the question editor.
Writes make one request and preserve the usual validation, permission, missing-question, and conflict errors.
The mock supports question reads, filters, pagination, creation, updates, and version changes.
