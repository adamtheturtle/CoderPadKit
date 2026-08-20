//
//  CoderPadClient+Identity.swift
//  CoderPadKit
//
//  Path and numeric identity guards for Interview client methods.
//

import Foundation

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
}
