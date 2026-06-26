# ``CoderPadKit``

An unofficial Swift client for the CoderPad REST API.

## Overview

`CoderPadKit` is the lean wire layer for the [CoderPad](https://coderpad.io) REST API:
typed models for pads, questions, and organizations; encode-only request bodies; a raw
``CoderPadError``; and the ``CoderPadClient`` that drives them all. The client wraps a
generic paginated transport, so list calls follow every page, idempotent GETs retry on
transient failures, and JSON decoding happens off the main actor.

The library is deliberately presentation-free and locale-free: it carries the facts the
API returns and leaves how to phrase or display them to you. The companion
`CoderPadKitMock` product ships an in-process fake of the API, backed by canned
fixtures, for demo modes and tests with no network.

> Note: This is an unofficial client and is not affiliated with or endorsed by CoderPad.

## Getting started

Construct a client with an API key, then call the typed endpoint methods:

```swift
import CoderPadKit

let client = CoderPadClient(apiKey: "your-api-key")

let pads = try await client.listPads(sort: "updated_at,desc")
let created = try await client.createPad(PadCreate(title: "Phone screen", language: "swift"))
let org = try await client.organization()
```

For self-hosted or regional deployments, pass a custom `baseURL`.

### Progressive loading

The incremental list methods yield growing snapshots, so a UI can render page one after a
single round-trip and append the rest as it arrives:

```swift
for try await snapshot in client.listPadsIncrementally() {
    render(snapshot)
}
```

### Testing without a network

Add the `CoderPadKitMock` product and use the mock client, which serves canned fixtures
over an in-process `URLProtocol`:

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
- ``PadEvent``
- ``PadEnvironment``
- ``PadEnvironmentFile``
- ``PadCreate``
- ``PadUpdate``

### Questions

- ``Question``
- ``InterviewType``
- ``QuestionCustomFile``
- ``QuestionTestCase``
- ``CandidateInstruction``
- ``CandidateInstructionPayload``
- ``QuestionCreate``
- ``QuestionUpdate``

### Organization

- ``Organization``
- ``OrganizationUser``
- ``OrganizationStats``
- ``Quota``
