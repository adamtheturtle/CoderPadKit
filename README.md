# CoderPadKit

An unofficial Swift client for the CoderPad REST API, with typed models and a no-network
mock backend.

[Documentation](https://swiftpackageindex.com/adamtheturtle/CoderPadKit/documentation/coderpadkit) |
[Swift Package Index](https://swiftpackageindex.com/adamtheturtle/CoderPadKit)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/CoderPadKit.git", from: "0.1.3")
```

Add `CoderPadKit` to your app target and `CoderPadKitMock` to tests or demos that should
run without the network.

## Products

- `CoderPadKit`: Typed API client for pads (including editor-history replay), questions,
  organizations, and quota data.
- `CoderPadKitMock`: In-process fake API seeded with canned data.

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+

## License

MIT. See [LICENSE](LICENSE).
