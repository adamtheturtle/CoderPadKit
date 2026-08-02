# CoderPadKit

An unofficial Swift client for the CoderPad REST API, with typed models and a no-network
mock backend.

[Documentation](https://swiftpackageindex.com/adamtheturtle/CoderPadKit/documentation/coderpadkit) |
[Swift Package Index](https://swiftpackageindex.com/adamtheturtle/CoderPadKit) |
[Release notes](CHANGELOG.md)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/CoderPadKit.git", from: "0.1.3")
```

Add `CoderPadKit` to your app target and `CoderPadKitMock` to tests or demos that should
run without the network.

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

`fileContents` is mutually exclusive with the legacy single-file `contents` property
and ZIP uploads; conflicting requests fail locally before networking.

## Products

- `CoderPadKit`: Typed API client for pads (including editor-history replay), questions,
  organizations, and quota data.
- `CoderPadKitMock`: In-process fake API seeded with canned data.

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+

## License

MIT. See [LICENSE](LICENSE).
