# Release notes

## Unreleased

## 0.5.16

- Decode paged pad, question, and event responses element-by-element, so a record the
  per-record validation rejects is dropped from its page instead of failing it. 0.5.14
  added several checks that reject a whole `Pad` or `Question` — the id shape, the
  lifecycle ordering, nonnegative counts — while `PadsPage.pads` was a plain `[Pad]`,
  so any one of them meant "an error and no pads at all" for a caller whose other 49
  records were fine. The number dropped is logged. The validation is unchanged; it is
  no longer destructive.

## 0.5.15

- Report contradictory lifecycle timestamps instead of refusing to decode the record.
  0.5.14 made `Pad` throw a `DecodingError` when `updated_at` preceded `created_at`,
  when `ended_at` preceded `created_at`, or when `ended_at` was set on a pad whose
  state was started/active/running/pending/draft, and made `Question` throw on the
  same `updated_at` ordering. Ordinary clock skew between the two writes is enough to
  produce one. Those records decode again, and the contradictions are exposed as
  `Pad.lifecycleInconsistencies` / `Question.lifecycleInconsistencies` and the
  `lifecycleDiagnostic` sentence, matching how malformed sub-elements are already
  skipped, counted, and surfaced through `omitted*Diagnostic`.

## 0.5.14

- **Breaking, undocumented at the time:** `PadEvent` no longer conforms to
  `Identifiable` and its synthesized `id` (`"<instant>-<kind>-<user>-<message>"`) is
  gone. Callers that used it for view identity or feed signatures must derive their
  own.
- **Breaking:** the memberwise initializers of `Pad`, `ScreenCampaign`,
  `ScreenTestSession`, and `ScreenReport` now `throw`, validating ids, names, scores,
  and timestamps. Previews and fixtures that built these values need `try`.
- **Breaking:** `PadCreate.teamID` and `PadUpdate.teamID` must be a canonical UUID or
  the mutation is rejected before networking with
  `PadMutationValidationError.invalidTeamID`, matching the Interview API's documented
  `team_id` type.
- **Breaking:** `Pad.webURL` and `Pad.playbackURL` now go through `OpenableHTTPSURL`,
  which accepts `https` only, so a pad served over plain `http` yields `nil` and
  callers fall back to their own base URL.

- Encode pad ownership mutations as `user_email`, matching the Interview create/modify
  pad contract. `PadCreate` and `PadUpdate` previously sent the response-only
  `owner_email` field, so ownership changes could be ignored.
- Add typed structured-file support to question creation and updates. Pass
  `QuestionFileContent` values through `QuestionCreate.fileContents` or
  `QuestionUpdate.fileContents`; CoderPadKit sends them as `question[file_contents]`
  and rejects conflicting starter-content representations before networking.
- Add data-oriented ZIP uploads to question creation and updates. Pass a
  `QuestionZIPUpload(data:filename:)` as the `zipFile` argument to `createQuestion` or
  `updateQuestion`; CoderPadKit sends it as `question[zip_file]` using multipart form
  data and rejects any simultaneous starter-content representation before networking.
