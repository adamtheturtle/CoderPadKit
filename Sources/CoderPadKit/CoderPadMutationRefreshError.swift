//
//  CoderPadMutationRefreshError.swift
//  CoderPadKit
//

import Foundation

/// A mutation was accepted by CoderPad, but fetching the resource's fresh state failed.
///
/// The write has already succeeded when this error is thrown. Callers must not blindly
/// retry the mutation; they can retain an optimistic local value and retry only the
/// refresh instead.
public nonisolated struct CoderPadMutationRefreshError: Error, CustomStringConvertible, Sendable {
    /// The resource whose write succeeded and whose refresh failed.
    public nonisolated enum Target: Equatable, Sendable {
        case pad(id: String)
        case question(id: Int)
    }

    public let target: Target
    public let refreshError: CoderPadError

    public var description: String {
        "Mutation succeeded for \(targetDescription), but refresh failed: \(refreshError)"
    }

    public init(target: Target, refreshError: CoderPadError) {
        self.target = target
        self.refreshError = refreshError
    }

    init(target: Target, underlying error: any Error) {
        self.init(
            target: target,
            refreshError: (error as? CoderPadError)
                ?? .decode("Unexpected refresh failure: \(String(describing: error))")
        )
    }

    private var targetDescription: String {
        switch target {
        case let .pad(id):
            "pad \(id)"
        case let .question(id):
            "question \(id)"
        }
    }
}
