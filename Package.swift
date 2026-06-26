// swift-tools-version: 6.2
import PackageDescription

/// Shared Swift settings. The `nonisolated` annotations throughout the sources are
/// written against `MainActor` default isolation so the request, pagination, and
/// decoding paths can run off the main actor.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
    // SWIFT_APPROACHABLE_CONCURRENCY: the file's `nonisolated` async methods run on
    // the caller's actor (SE-0461) rather than hopping to the main actor.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

/// An unofficial Swift client for the CoderPad REST API.
///
/// `CoderPadKit` is the lean wire layer: typed models, request bodies, a raw error
/// type, and the `CoderPadClient` that drives them over the `PaginatedRESTClient`
/// transport. `CoderPadKitMock` is an opt-in in-process fake of the API, backed by
/// canned fixtures, for demo modes and tests with no network.
///
/// Both targets use the Swift 6 language mode with `MainActor` default actor
/// isolation, against which the source's `nonisolated` annotations are written so the
/// networking and decoding can run off the main actor.
let package = Package(
    name: "CoderPadKit",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "CoderPadKit", targets: ["CoderPadKit"]),
        .library(name: "CoderPadKitMock", targets: ["CoderPadKitMock"])
    ],
    dependencies: [
        .package(url: "https://github.com/adamtheturtle/PaginatedRESTClient.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "CoderPadKit",
            dependencies: [
                .product(name: "PaginatedRESTClient", package: "PaginatedRESTClient")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CoderPadKitMock",
            dependencies: ["CoderPadKit"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CoderPadKitTests",
            dependencies: ["CoderPadKit", "CoderPadKitMock"],
            swiftSettings: swiftSettings
        )
    ]
)
