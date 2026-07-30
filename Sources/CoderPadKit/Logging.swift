//
//  Logging.swift
//  CoderPadKit
//

import Foundation

/// The package's logger. Decode failures are logged here (rather than swallowed) so
/// silent API drift shows up in Console instead of producing empty data with no
/// diagnostic.
#if canImport(OSLog)
    import OSLog

    nonisolated struct CoderPadLogger {
        private let logger: Logger

        init(category: String) {
            logger = Logger(subsystem: "com.coderpad.CoderPadKit", category: category)
        }

        func debug(_ message: String) {
            logger.debug("\(message, privacy: .public)")
        }

        func error(_ message: String) {
            logger.error("\(message, privacy: .public)")
        }
    }
#else
    nonisolated struct CoderPadLogger {
        init(category _: String) {}
        func debug(_: String) {}
        func error(_: String) {}
    }
#endif

nonisolated let apiLogger = CoderPadLogger(category: "api")

extension KeyedDecodingContainer {
    /// Like `try? decodeIfPresent`, but logs the underlying error so silent API drift
    /// shows up in Console rather than producing an empty model with no diagnostic.
    nonisolated func loggedDecodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            apiLogger.debug(
                """
                decodeIfPresent '\(key.stringValue)' \
                as \(String(describing: type)) \
                failed: \(error.localizedDescription)
                """
            )
            return nil
        }
    }
}
