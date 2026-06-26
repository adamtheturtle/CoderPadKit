//
//  Logging.swift
//  CoderPadKit
//

import Foundation
import os.log

/// The package's logger. Decode failures are logged here (rather than swallowed) so
/// silent API drift shows up in Console instead of producing empty data with no
/// diagnostic.
nonisolated let apiLogger = Logger(subsystem: "com.coderpad.CoderPadKit", category: "api")

extension KeyedDecodingContainer {
    /// Like `try? decodeIfPresent`, but logs the underlying error so silent API drift
    /// shows up in Console rather than producing an empty model with no diagnostic.
    nonisolated func loggedDecodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            apiLogger.debug(
                """
                decodeIfPresent '\(key.stringValue, privacy: .public)' \
                as \(String(describing: type), privacy: .public) \
                failed: \(error.localizedDescription, privacy: .public)
                """
            )
            return nil
        }
    }
}
