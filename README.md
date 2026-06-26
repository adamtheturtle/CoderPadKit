# CoderPadKit

An unofficial Swift client for the [CoderPad](https://coderpad.io) REST API: typed pads,
questions, and organizations, plus a no-network mock backend.

[![CI](https://github.com/adamtheturtle/CoderPadKit/actions/workflows/ci.yml/badge.svg)](https://github.com/adamtheturtle/CoderPadKit/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fadamtheturtle%2FCoderPadKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/adamtheturtle/CoderPadKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fadamtheturtle%2FCoderPadKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/adamtheturtle/CoderPadKit)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`CoderPadKit` is the lean wire layer for the CoderPad REST API: typed models for pads,
questions, and organizations; encode-only request bodies; a raw `CoderPadError`; and a
`CoderPadClient` that drives them all. The client wraps a generic paginated transport, so
list calls follow every page, idempotent GETs retry on transient failures, and JSON
decoding happens off the main actor.

The library stays presentation-free and locale-free: it carries the facts the API returns
and leaves how to phrase or display them to you. The companion `CoderPadKitMock` product
ships an in-process fake of the API, backed by canned fixtures, for demo modes and tests
with no network.

> This is an unofficial client and is not affiliated with or endorsed by CoderPad.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/adamtheturtle/CoderPadKit.git", from: "0.1.0")
]
```

Add `CoderPadKit` to your target's dependencies, and `CoderPadKitMock` to your test
target if you want the in-process fake. In Xcode, use **File > Add Package Dependencies**
and paste the repository URL.

## Quick start

```swift
import CoderPadKit

let client = CoderPadClient(apiKey: "your-api-key")

// List, following every page.
let pads = try await client.listPads(sort: "updated_at,desc")

// Create and modify.
let created = try await client.createPad(PadCreate(title: "Phone screen", language: "swift"))
let renamed = try await client.updatePad(PadUpdate(id: created.id, title: "Onsite"))

// Organization and quota.
let org = try await client.organization()
let quota = try await client.quota()
```

For self-hosted or regional deployments, pass a custom `baseURL`:

```swift
let client = CoderPadClient(apiKey: key, baseURL: URL(string: "https://coderpad.example.com")!)
```

### Progressive loading

The incremental list methods stream growing snapshots, so a UI can render the first page
after a single round-trip and append the rest as later pages arrive:

```swift
for try await snapshot in client.listPadsIncrementally() {
    render(snapshot) // page 1 first, then larger cumulative snapshots
}
```

### Testing without a network

```swift
import CoderPadKit
import CoderPadKitMock

let client = CoderPadClient.mock()                   // seeded demo data
let badKey = CoderPadClient.mock(unauthorized: true) // every request answers 401
```

## Errors

`CoderPadError` is intentionally raw and locale-free. To present user-facing, localized
messages, conform it to `LocalizedError` in your app and map the cases to your own copy:

```swift
extension CoderPadError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: String(localized: "Add an API key in Settings.")
        case let .http(code, _): ... // map status codes to your copy
        case .decode: String(localized: "Could not read the response.")
        case .network: String(localized: "You appear to be offline.")
        }
    }
}
```

## Documentation

Full API documentation is hosted on the
[Swift Package Index](https://swiftpackageindex.com/adamtheturtle/CoderPadKit/documentation).

## License

MIT. See [LICENSE](LICENSE).
