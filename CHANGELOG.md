# Release notes

## Unreleased

- Add data-oriented ZIP uploads to question creation and updates. Pass a
  `QuestionZIPUpload(data:filename:)` as the `zipFile` argument to `createQuestion` or
  `updateQuestion`; CoderPadKit sends it as `question[zip_file]` using multipart form
  data and rejects a simultaneous single-file `contents` value before networking.
