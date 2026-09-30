# ``CoderPadKit``

An unofficial Swift client for the CoderPad REST API.

## Overview

`CoderPadKit` is the lean wire layer for the [CoderPad](https://coderpad.io) REST API: typed models for pads, questions, and organizations; encode-only request bodies; a raw ``CoderPadError``; and the ``CoderPadClient`` that drives them all.
The client wraps a generic paginated transport, so list calls follow every page, idempotent GETs retry on transient failures, and JSON decoding happens off the main actor.

The library is deliberately presentation-free and locale-free: it carries the facts the API returns and leaves how to phrase or display them to you.
The companion `CoderPadKitMock` product ships an in-process fake of the API, backed by canned fixtures, for demo modes and tests with no network.

> Note: This is an unofficial client and is not affiliated with or endorsed by CoderPad.

### Empirically observed metadata

Some read-only fields exposed by the live service are absent from the published API contract.
CoderPadKit retains the observed `PadEnvironmentFile.binary`, `Pad.restrictInterviewerAccess`, `Pad.padInterviewerNotifications`, and `Question.customDatabase` metadata with typed models.
These fields may evolve without the guarantees of the published contract.
`Organization.child_organizations` remains deliberately unmodelled until a non-empty response confirms its item shape.

## Getting started

Construct a client with an API key, then call the typed endpoint methods:

```swift
import CoderPadKit

let client = CoderPadClient(apiKey: "your-api-key")

let pads = try await client.listPads(sort: "updated_at,desc")
let created = try await client.createPad(PadCreate(title: "Phone screen", language: "swift"))
let org = try await client.organization()
```

### Multi-file questions

Create a framework or project question by supplying its starter files as ``QuestionFileContent`` values.
Paths may include directories, and text contents may be empty or contain Unicode:

```swift
let question = try await client.createQuestion(QuestionCreate(
    title: "Refactor the greeting service",
    language: "multifile_python",
    fileContents: [
        QuestionFileContent(path: "main.py", contents: "from greeting import greet\n"),
        QuestionFileContent(path: "greeting.py", contents: "def greet(name):\n    return f'Hello, {name}!'\n"),
        QuestionFileContent(path: "tests/__init__.py", contents: "")
    ]
))

try await client.updateQuestionWithoutRefetch(QuestionUpdate(
    id: question.id,
    fileContents: [
        QuestionFileContent(path: "main.py", contents: "print('Hello, 世界')\n")
    ]
))
```

Alternatively, create or replace a multi-file question by supplying archive bytes and their wire filename.
CoderPadKit does not read the filesystem; the data can come from memory, a file provider, a download, or any other source:

```swift
let upload = QuestionZIPUpload(data: archiveData, filename: "starter-project.zip")

let question = try await client.createQuestion(
    QuestionCreate(title: "Refactor the service", language: "multifile_swift"),
    zipFile: upload
)

_ = try await client.updateQuestion(
    QuestionUpdate(id: question.id, description: "Updated requirements"),
    zipFile: upload
)
```

The legacy ``QuestionCreate/contents`` and ``QuestionUpdate/contents`` properties remain available for single-file questions.
`contents`, `fileContents`, and a ZIP upload are mutually exclusive; conflicting inputs throw ``QuestionMutationValidationError`` before any request is sent.

CoderPad Screen uses a separate host and `API-Key` authentication.
Create a ``ScreenClient`` to list campaigns and candidate sessions, send invitations, retrieve reports, or manage the organization webhook:

```swift
let screen = ScreenClient.live(apiKey: "your-screen-api-key")
let campaigns = try await screen.listCampaigns()
let sessions = try await screen.listAllTests(campaignID: campaigns.first?.id)
```

Fetch and replay a file's editor history using the URL returned by its pad environment:

```swift
let environment = try await client.padEnvironment(id: 123)
if let file = environment.fileContents.first, let historyURL = file.history {
    let history = try await client.padHistory(historyURL: historyURL)
    let latestContents = history.replay()
}
```

For self-hosted or regional deployments, pass a custom `baseURL`.

### Progressive loading

The incremental list methods yield growing snapshots, so a UI can render page one after a single round-trip and append the rest as it arrives:

```swift
for try await snapshot in client.listPadsIncrementally() {
    render(snapshot)
}
```

### Testing without a network

Add the `CoderPadKitMock` product and use the mock client, which serves canned fixtures over an in-process `URLProtocol`:

```swift
import CoderPadKitMock

let client = CoderPadClient.mock()                 // seeded demo data
let badKey = CoderPadClient.mock(unauthorized: true) // every request answers 401
```

## Topics

### The client

- ``CoderPadClient``
- ``CoderPadError``

### Pads

- ``Pad``
- ``PadState``
- ``PadTeam``
- ``PadInterviewerNotification``
- ``PadEvent``
- ``PadEnvironment``
- ``PadEnvironmentFile``
- ``PadHistory``
- ``PadHistoryEntry``
- ``PadHistoryOperation``
- ``PadCreate``
- ``PadUpdate``
- ``PadMutationValidationError``

### Questions

- ``Question``
- ``InterviewType``
- ``QuestionCustomFile``
- ``QuestionCustomDatabase``
- ``QuestionCustomDatabaseSchema``
- ``QuestionCustomDatabaseTable``
- ``QuestionCustomDatabaseColumn``
- ``QuestionTestCase``
- ``CandidateInstruction``
- ``CandidateInstructionPayload``
- ``QuestionFileContent``
- ``QuestionCreate``
- ``QuestionUpdate``
- ``QuestionZIPUpload``
- ``QuestionMutationValidationError``

### Organization

- ``Organization``
- ``OrganizationUser``
- ``OrganizationStats``
- ``Quota``

### Screen

- ``ScreenClient``
- ``ScreenCampaign``
- ``ScreenInvitation``
- ``ScreenInvitationResult``
- ``ScreenTestSession``
- ``ScreenTestQuestion``
- ``ScreenReport``
- ``ScreenTechnologyResult``
- ``ScreenSkillResult``
- ``ScreenPagination``


## Question variants

Variants use JSON routes nested under a question.
A language key or project-template slug is required when creating one:

```swift
let variant = try await client.createQuestionVariant(
    questionID: 101, .init(language: "ruby", contents: .value("puts 1"))
)
let variants = try await client.listQuestionVariants(questionID: 101)
_ = try await client.getQuestionVariant(questionID: 101, id: variant.id)
_ = try await client.updateQuestionVariant(
    questionID: 101, id: variant.id, .init(contents: .languageDefault)
)
try await client.deleteQuestionVariant(questionID: 101, id: variant.id)
```

`contents: .unchanged` omits starter code; `.value("")` writes a blank file; `.languageDefault` sends JSON null.
Changing environments clears starter code unless replacement contents or files accompany the change.
Contents and files are mutually exclusive.
File entries preserve decoded paths and optional `hidden` / `deleted` flags.
Alternatively, `fileContentsJSON` sends a JSON string under `file_contents`.
Template files are overlaid on create and replaced on update; an empty array on update resets the template.
The API protects `.cpad` and requires a remaining file.
