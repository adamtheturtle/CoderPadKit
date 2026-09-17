//
//  CoderPadClient+Identity.swift
//  CoderPadKit
//
//  Path and numeric identity guards for Interview client methods.
//

import Foundation
import PaginatedRESTClient

extension CoderPadClient {
    nonisolated static func validatePadID(_ id: String) throws {
        let allowed = id.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "-._~".unicodeScalars.contains(scalar))
        }
        guard !id.isEmpty, id != ".", id != "..", allowed else {
            throw CoderPadError.decode("Pad ID must be one non-empty URL path component.")
        }
    }

    /// Rejects zero and negative Interview resource IDs before they are interpolated
    /// into request paths (#100, #102).
    nonisolated static func validatePositiveResourceID(_ id: Int, kind: String) throws {
        guard id > 0 else {
            throw CoderPadError.decode("Interview \(kind) ID must be positive.")
        }
    }

    /// Validates `sort` before opening a page stream so unsupported values fail
    /// without starting network I/O (#154).
    func validatedSortStream<Element: Sendable>(
        sort: String?,
        makeStream: (String?) -> PaginatedRESTPageStream<[Element]>
    ) -> AsyncThrowingStream<[Element], any Error> {
        do {
            let pages = makeStream(try InterviewListSort.validated(sort))
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await page in pages {
                            continuation.yield(page)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }
}
