//
//  CoderPadRetryPolicy.swift
//  CoderPadKit
//
//  Shared classification of retry-worthy transport and HTTP failures for idempotent
//  Interview and Screen GETs (#160, #164).
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

enum CoderPadRetryPolicy {
    /// URLError codes treated as brief, retryable connectivity problems.
    nonisolated static let transientURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .notConnectedToInternet
    ]

    private nonisolated static let transientNSURLErrorCodes: Set<Int> = Set(
        transientURLErrorCodes.map(\.rawValue)
    )

    /// Whether an already-mapped or raw transport failure should be retried on an
    /// idempotent GET.
    nonisolated static func isTransient(_ error: any Error) -> Bool {
        if error is CancellationError { return false }

        if let api = error as? CoderPadError {
            if case let .http(code, _) = api {
                return isTransientHTTPStatus(code)
            }
            if case let .network(urlError) = api {
                return transientURLErrorCodes.contains(urlError.code)
            }
            return false
        }

        if let urlError = error as? URLError {
            return transientURLErrorCodes.contains(urlError.code)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return transientNSURLErrorCodes.contains(nsError.code)
        }
        return false
    }

    nonisolated static func isTransientHTTPStatus(_ code: Int) -> Bool {
        (500 ... 599).contains(code) || code == 429 || code == 408 || code == 0
    }

    /// Matches PaginatedRESTClient's 300ms → 600ms exponential policy.
    nonisolated static func backoffDelay(retryNumber: Int) -> TimeInterval {
        let exponent = Double(max(0, retryNumber - 1))
        return min(60, 0.3 * pow(2, exponent))
    }
}
