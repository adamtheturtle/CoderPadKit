# Release notes

## Unreleased

- Add typed structured-file support to question creation and updates. Pass
  `QuestionFileContent` values through `QuestionCreate.fileContents` or
  `QuestionUpdate.fileContents`; CoderPadKit sends them as `question[file_contents]`
  and rejects conflicting starter-content representations before networking.
- Add data-oriented ZIP uploads to question creation and updates. Pass a
  `QuestionZIPUpload(data:filename:)` as the `zipFile` argument to `createQuestion` or
  `updateQuestion`; CoderPadKit sends it as `question[zip_file]` using multipart form
  data and rejects any simultaneous starter-content representation before networking.
