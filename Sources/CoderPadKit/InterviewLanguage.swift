//
//  InterviewLanguage.swift
//  CoderPadKit
//
//  Known Interview API language identifiers and encode-time validation (#155).
//

import Foundation

/// Known Interview API language / framework identifiers used when creating or
/// updating pads and questions. The set is intentionally broad (classic single-file
/// codes, multifile project prefixes, and common framework spellings). Pass
/// `allowUnknown: true` to opt into forward-compatible identifiers the package has
/// not catalogued yet (#155).
public nonisolated enum InterviewLanguage {
    /// Documented and historically observed wire values for the Interview API.
    public static let knownIdentifiers: Set<String> = [
        "angular", "bash", "c", "clojure", "coffeescript", "cpp", "csharp", "dart",
        "django", "elixir", "erlang", "fsharp", "gin", "go", "hack", "haskell",
        "html", "html_css_js", "java", "javascript", "julia", "kotlin", "lua",
        "markdown", "mysql", "nextjs", "node", "objc", "objective-c", "objectivec",
        "ocaml", "perl", "php", "plaintext", "postgresql", "powershell", "python",
        "python2", "python3", "r", "rails", "react", "react_native", "ruby", "rust",
        "scala", "solidity", "spring", "sql", "sqlite", "svelte", "swift", "swift5",
        "tcl", "terraform", "typescript", "vb", "vbnet", "verilog", "visualbasic",
        "vue",
        "multifile_c", "multifile_cpp", "multifile_csharp", "multifile_go",
        "multifile_java", "multifile_javascript", "multifile_python",
        "multifile_ruby", "multifile_rust", "multifile_swift", "multifile_typescript",
    ]

    /// Trims whitespace and requires a nonempty identifier. Unless `allowUnknown` is
    /// set, the value must be in ``knownIdentifiers``.
    public static func validated(
        _ language: String?,
        allowUnknown: Bool = false
    ) throws -> String? {
        guard let language else { return nil }
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CoderPadError.decode(
                "Language must not be blank."
            )
        }
        if !allowUnknown, !knownIdentifiers.contains(trimmed) {
            throw CoderPadError.decode(
                "Language '\(trimmed)' is not a known Interview language identifier."
            )
        }
        return trimmed
    }
}

/// Documented list `sort` values: a field of `created_at` or `updated_at` combined
/// with a direction of `asc` or `desc` (#154).
public nonisolated enum InterviewListSort: String, CaseIterable, Hashable, Sendable {
    case createdAtAsc = "created_at,asc"
    case createdAtDesc = "created_at,desc"
    case updatedAtAsc = "updated_at,asc"
    case updatedAtDesc = "updated_at,desc"

    /// Accepts a combined `field,direction` string, or `nil` (API default).
    public static func validated(_ sort: String?) throws -> String? {
        guard let sort else { return nil }
        let trimmed = sort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CoderPadError.decode(
                "List sort must be created_at|updated_at with direction asc|desc."
            )
        }
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard parts.count == 2,
              ["created_at", "updated_at"].contains(parts[0]),
              ["asc", "desc"].contains(parts[1])
        else {
            throw CoderPadError.decode(
                "List sort must be created_at|updated_at with direction asc|desc."
            )
        }
        return "\(parts[0]),\(parts[1])"
    }
}
