//
//  ScreenReportFiles.swift
//  coderpad
//
//  Temporary-file handling for opened Screen report PDFs (#804, #807). Reports carry
//  candidate identity, scores, and proctoring data, and Screen test IDs are only unique
//  within one organization, so each opened report is staged in its own single-use
//  subdirectory (restrictive permissions, unique path per invocation - reports from two
//  accounts with the same test ID can never overwrite each other) and deleted again:
//  shortly after the viewer has opened it, and at the next launch for anything left
//  behind by an earlier run.
//

import Foundation
import Synchronization

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

public nonisolated enum ScreenReportFiles {
    private static let logger = CoderPadLogger(category: "screen-reports")

    /// Folders staged by this process (keyed by their unique directory name), each
    /// with its scheduled removal task when one exists. The registry keeps the launch
    /// sweep from deleting a report staged concurrently (#1947), lets an explicit
    /// removal cancel its now-pointless scheduled task (#1117, #1948), and makes both
    /// paths idempotent.
    private static let active = Mutex([String: Task<Void, Never>?]())

    /// Every PDF starts with this marker (#1943).
    public static let pdfMagic = Array("%PDF-".utf8)
    /// Trailer marker required by the PDF file structure (#171).
    public static let pdfEOFMarker = Array("%%EOF".utf8)
    /// Cross-reference locator required near the end of a PDF (#171).
    public static let pdfStartXRefMarker = Array("startxref".utf8)
    /// Generous ceiling for one candidate report, enforced at the staging boundary
    /// as well as before the open/save choice (#2720).
    public static let maxReportBytes = 50 * 1024 * 1024
    /// Fail-safe expiry scheduled when a report is staged so forgotten cleanup
    /// cannot retain candidate data for the whole process lifetime (#172).
    public static let defaultStageExpiry: Duration = .seconds(3600)

    public static func isWithinSizeLimit(_ byteCount: Int) -> Bool {
        byteCount >= 0 && byteCount <= maxReportBytes
    }

    /// Whether the bytes plausibly are a PDF document. Always requires a bounded
    /// structural check (`%PDF-`, `startxref`, `%%EOF`); on platforms with
    /// CoreGraphics, also requires a parseable document with at least one page
    /// (#171).
    public static func isLikelyPDF(_ data: Data) -> Bool {
        guard hasPDFStructure(data) else { return false }
        #if canImport(CoreGraphics)
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider)
        else { return false }

        return document.numberOfPages > 0
        #else
        return true
        #endif
    }

    /// Platform-independent structural PDF check used before any CoreGraphics parse.
    static func hasPDFStructure(_ data: Data) -> Bool {
        guard data.starts(with: pdfMagic), data.count >= pdfMagic.count + pdfEOFMarker.count else {
            return false
        }
        let trailerWindow = data.suffix(min(2048, data.count))
        guard trailerWindow.range(of: Data(pdfEOFMarker)) != nil else { return false }
        // `startxref` may sit just before the trailer; search the same trailing window.
        return trailerWindow.range(of: Data(pdfStartXRefMarker)) != nil
            || data.range(of: Data(pdfStartXRefMarker)) != nil
    }

    /// The root folder under the app's temporary directory that holds every staged
    /// report, so launch cleanup can sweep them all in one pass.
    static var stagingRoot: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenReports", isDirectory: true)
    }

    /// Writes report data to a fresh single-use subdirectory (owner-only permissions)
    /// and returns the file URL to hand to the viewer. The filename keeps the test ID
    /// so the window title in Preview stays meaningful; uniqueness comes from the
    /// enclosing directory.
    public static func stage(_ data: Data, testID: Int) throws -> URL {
        try stage(data, testID: testID, failSafeAfter: defaultStageExpiry, afterCreatingFolder: { _ in })
    }

    static func stage(
        _ data: Data,
        testID: Int,
        failSafeAfter: Duration = defaultStageExpiry,
        afterCreatingFolder: @Sendable (URL) -> Void
    ) throws -> URL {
        guard testID > 0 else { throw CocoaError(.fileWriteInvalidFileName) }
        guard isWithinSizeLimit(data.count) else { throw CocoaError(.fileWriteOutOfSpace) }

        // Never put non-PDF bytes under a .pdf name for an external viewer, even if
        // a caller forgot its own validation (#1943).
        guard isLikelyPDF(data) else { throw CocoaError(.fileWriteUnknown) }

        let name = UUID().uuidString
        let folder = stagingRoot.appendingPathComponent(name, isDirectory: true)
        let url = folder.appendingPathComponent("ScreenReport-\(testID).pdf")
        // Reserve the name before the directory becomes visible. A concurrent launch
        // sweep snapshots this registry and therefore cannot mistake an in-progress
        // write for an abandoned report.
        active.withLock { $0[name] = .some(nil) }
        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            afterCreatingFolder(folder)
            // Atomic, so the viewer can never observe a partially written report
            // (#1115), and owner-only like its folder (#1385, #1949).
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // A failed write must not leave the sensitive single-use folder behind
            // (#1942).
            _ = active.withLock { $0.removeValue(forKey: name) }
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        // Schedule fail-safe cleanup even when the caller never calls
        // `scheduleRemoval` / `handleOpenResult` (#172).
        scheduleRemoval(of: url, after: failSafeAfter)
        return url
    }

    /// Removes one staged report (its whole single-use subdirectory), cancelling any
    /// removal still scheduled for it (#1117). Deleting a file an external viewer has
    /// open is safe: the viewer's handle (or in-memory copy) keeps the data readable;
    /// the unlink only removes the name.
    public static func remove(_ url: URL) {
        remove(url, retryAfter: .seconds(30)) { try FileManager.default.removeItem(at: $0) }
    }

    static func remove(
        _ url: URL,
        retryAfter: Duration,
        removeItem: @escaping @Sendable (URL) throws -> Void
    ) {
        // Only ever delete inside the staging root: a caller passing an unexpected
        // URL must not be able to remove an arbitrary parent directory (#1946).
        guard let folder = stagedFolder(containing: url) else {
            logger.error("Refused to remove a Screen report outside the staging root.")
            return
        }

        let scheduled = active.withLock { $0.removeValue(forKey: folder.lastPathComponent) }
        if let scheduled, let scheduled { scheduled.cancel() }
        do {
            try removeItem(folder)
        } catch CocoaError.fileNoSuchFile {
            // Already swept; both cleanup paths are idempotent (#1948).
        } catch {
            // Keep a retry registered so the launch sweep cannot mistake sensitive
            // data from this process for an abandoned directory and race it (#1947).
            logger.error("Couldn't remove a staged Screen report: \(error.localizedDescription)")
            scheduleRemovalAttempt(
                of: url,
                after: retryAfter,
                retryAfter: retryAfter,
                removeItem: removeItem
            )
        }
    }

    /// Removes a staged report once the viewer has had ample time to load it. If the
    /// app quits before the delay elapses, `cleanUpLeftovers()` sweeps it next launch.
    public static func scheduleRemoval(of url: URL, after duration: Duration = .seconds(300)) {
        scheduleRemovalAttempt(of: url, after: duration, retryAfter: .seconds(30)) {
            try FileManager.default.removeItem(at: $0)
        }
    }

    private static func scheduleRemovalAttempt(
        of url: URL,
        after duration: Duration,
        retryAfter: Duration,
        removeItem: @escaping @Sendable (URL) throws -> Void
    ) {
        // Validate before constructing a task or touching `active`: an outside URL with
        // a colliding folder name must not cancel cleanup for a legitimate report.
        guard let folder = stagedFolder(containing: url) else {
            logger.error("Refused to schedule removal outside the staging root.")
            return
        }
        let name = folder.lastPathComponent
        let task = Task.detached(priority: .utility) {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }

            remove(url, retryAfter: retryAfter, removeItem: removeItem)
        }
        active.withLock { registry in
            if let previous = registry[name], let previous { previous.cancel() }
            registry[name] = task
        }
    }

    /// Returns the report's single-use folder only when it is a direct child of the
    /// staging root. Keeping this check shared prevents scheduled and immediate removal
    /// from drifting into different containment policies.
    private static func stagedFolder(containing url: URL) -> URL? {
        let folder = url.deletingLastPathComponent().standardizedFileURL
        guard folder.deletingLastPathComponent().standardizedFileURL.path
            == stagingRoot.standardizedFileURL.path else { return nil }
        return folder
    }

    /// A rejected workspace launch has no viewer that needs the staged bytes, so
    /// remove candidate data immediately instead of waiting for the delayed sweep.
    public static func handleOpenResult(_ accepted: Bool, for url: URL) {
        if accepted {
            scheduleRemoval(of: url)
        } else {
            remove(url)
        }
    }

    /// Launch-time sweep of reports left behind by earlier runs (e.g. the app quit
    /// before a scheduled removal fired). Reports staged by this process are skipped,
    /// so a late sweep can't race a concurrently opened report (#1947).
    public static func cleanUpLeftovers() {
        let manager = FileManager.default
        let entries: [URL]
        do {
            entries = try manager.contentsOfDirectory(at: stagingRoot, includingPropertiesForKeys: nil)
        } catch CocoaError.fileReadNoSuchFile {
            // Nothing was ever staged (or a prior sweep finished the job).
            return
        } catch {
            // Reports hold candidate data: a sweep that can't even list the
            // staging root must not pass silently as if it cleaned up (#1959).
            logger.error("Couldn't sweep leftover Screen reports: \(error.localizedDescription)")
            return
        }

        let live = active.withLock { Set($0.keys) }
        for entry in entries where !live.contains(entry.lastPathComponent) {
            do {
                try manager.removeItem(at: entry)
            } catch {
                logger.error("Couldn't sweep a leftover Screen report: \(error.localizedDescription)")
            }
        }
    }
}
