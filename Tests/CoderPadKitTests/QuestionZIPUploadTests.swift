//
//  QuestionZIPUploadTests.swift
//  CoderPadKitTests
//

@testable import CoderPadKit
import Foundation
import Synchronization
import Testing

@Suite("Question ZIP uploads", .serialized)
struct QuestionZIPUploadTests {
    @Test
    func `create sends a complete multipart request with Unicode filename`() async throws {
        let client = makeClient()
        let filename = "résumé \"draft\".zip"
        let fileData = Data([0x50, 0x4B, 0x03, 0x04])

        _ = try await client.createQuestion(
            QuestionCreate(
                title: "Unicode π",
                language: "multifile_python",
                description: "Two files",
                solution: "Done",
                takeHome: false,
                padType: "live",
                candidateInstructions: [
                    CandidateInstructionPayload(instructions: "Start here", defaultVisible: true)
                ],
                aiAssistCustomSystemPrompt: "Give hints"
            ),
            zipFile: QuestionZIPUpload(data: fileData, filename: filename)
        )

        let request = try #require(ZIPCaptureURLProtocol.requests().first)
        let boundary = try boundary(from: request.contentType)
        let expected = multipartBody(
            boundary: boundary,
            fields: [
                ("question[title]", "Unicode π"),
                ("question[language]", "multifile_python"),
                ("question[description]", "Two files"),
                ("question[solution]", "Done"),
                ("question[take_home]", "false"),
                ("question[pad_type]", "live"),
                (
                    "question[candidate_instructions]",
                    #"[{"default_visible":true,"instructions":"Start here"}]"#
                ),
                ("question[ai_assist_custom_system_prompt]", "Give hints")
            ],
            escapedFilename: "r_sum_ \\\"draft\\\".zip",
            filenameStar: "r%C3%A9sum%C3%A9%20%22draft%22.zip",
            fileData: fileData
        )

        #expect(request.method == "POST")
        #expect(request.path == "/api/questions")
        #expect(request.authorization == "Bearer test-key")
        #expect(request.accept == "application/json")
        #expect(request.contentType == "multipart/form-data; boundary=\(boundary)")
        #expect(request.bodyWasStreamed)
        #expect(request.body == expected)
    }

    @Test
    func `update sends ZIP bytes and ordinary fields before refetching`() async throws {
        let client = makeClient()
        let archive = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0xFF])

        _ = try await client.updateQuestion(
            QuestionUpdate(id: 42, title: "Replacement", language: "multifile_java"),
            zipFile: QuestionZIPUpload(data: archive, filename: "project.zip")
        )

        let requests = ZIPCaptureURLProtocol.requests()
        #expect(requests.count == 2)
        let request = try #require(requests.first)
        let boundary = try boundary(from: request.contentType)
        let expected = multipartBody(
            boundary: boundary,
            fields: [
                ("question[title]", "Replacement"),
                ("question[language]", "multifile_java")
            ],
            escapedFilename: "project.zip",
            fileData: archive
        )

        #expect(request.method == "PUT")
        #expect(request.path == "/api/questions/42")
        #expect(request.body == expected)
        #expect(request.bodyWasStreamed)
        #expect(requests.last?.method == "GET")
        #expect(requests.last?.path == "/api/questions/42")
    }

    @Test
    func `contents or structured files and ZIP fail before transport`() async {
        let client = makeClient()
        let upload = QuestionZIPUpload(data: Data(), filename: "empty.zip")

        await #expect(throws: QuestionMutationValidationError.self) {
            _ = try await client.createQuestion(
                QuestionCreate(title: "Conflict", contents: ""),
                zipFile: upload
            )
        }
        await #expect(throws: QuestionMutationValidationError.self) {
            _ = try await client.updateQuestion(
                QuestionUpdate(id: 42, contents: "starter"),
                zipFile: upload
            )
        }
        await #expect(throws: QuestionMutationValidationError.self) {
            _ = try await client.createQuestion(
                QuestionCreate(title: "Conflict", fileContents: []),
                zipFile: upload
            )
        }
        await #expect(throws: QuestionMutationValidationError.self) {
            _ = try await client.updateQuestion(
                QuestionUpdate(
                    id: 42,
                    fileContents: [QuestionFileContent(path: "main.py", contents: "")]
                ),
                zipFile: upload
            )
        }

        #expect(ZIPCaptureURLProtocol.requests().isEmpty)
    }

    @Test
    func `upload and request values are Sendable`() {
        requireSendable(CoderPadClient.self)
        requireSendable(QuestionZIPUpload.self)
        requireSendable(QuestionCreate.self)
        requireSendable(QuestionUpdate.self)
        requireSendable(QuestionMutationValidationError.self)
        requireSendable(QuestionZIPUploadTooLargeError.self)
        requireSendable(QuestionZIPUploadInvalidFilenameError.self)
        requireSendable(QuestionZIPUploadInvalidArchiveError.self)
        requireSendable(MultipartFormDataTooLargeError.self)
    }

    @Test(arguments: ["", "   ", "a/b.zip", "a\\b.zip", "bad\u{0000}.zip", "zw\u{200B}j.zip"])
    func `invalid ZIP filenames are rejected before staging`(_ filename: String) async {
        let client = makeClient()
        let error = await #expect(throws: QuestionZIPUploadInvalidFilenameError.self) {
            _ = try await client.createQuestion(
                QuestionCreate(title: "Bad name"),
                zipFile: QuestionZIPUpload(data: Data([0x50, 0x4B]), filename: filename)
            )
        }
        #expect(error?.filename == filename)
        #expect(ZIPCaptureURLProtocol.requests().isEmpty)
    }

    @Test
    func `oversized ZIP is rejected before staging or transport`() async throws {
        let client = makeClient()
        let upload = QuestionZIPUpload(
            data: Data(count: QuestionZIPUpload.maximumByteCount + 1),
            filename: "too-large.zip"
        )

        let error = await #expect(throws: QuestionZIPUploadTooLargeError.self) {
            _ = try await client.createQuestion(QuestionCreate(title: "Too large"), zipFile: upload)
        }

        #expect(error?.byteCount == QuestionZIPUpload.maximumByteCount + 1)
        #expect(error?.limit == QuestionZIPUpload.maximumByteCount)
        #expect(ZIPCaptureURLProtocol.requests().isEmpty)
    }

    @Test
    func `oversized multipart text fields are rejected during staging`() async throws {
        let client = makeClient()
        let oversizedDescription = String(
            repeating: "a",
            count: QuestionZIPUpload.maximumMultipartByteCount
        )

        let error = await #expect(throws: MultipartFormDataTooLargeError.self) {
            _ = try await client.createQuestion(
                QuestionCreate(title: "Tiny ZIP", description: oversizedDescription),
                zipFile: QuestionZIPUpload(data: Data([0x50, 0x4B]), filename: "tiny.zip")
            )
        }

        #expect(error?.limit == QuestionZIPUpload.maximumMultipartByteCount)
        #expect(ZIPCaptureURLProtocol.requests().isEmpty)
    }

    @Test
    func `large ZIP uses a staged file instead of an aggregate request body`() async throws {
        let client = makeClient()
        let archive = Data(repeating: 0xA5, count: 8 * 1024 * 1024)

        _ = try await client.createQuestion(
            QuestionCreate(title: "Large archive"),
            zipFile: QuestionZIPUpload(data: archive, filename: "large.zip")
        )

        let request = try #require(ZIPCaptureURLProtocol.requests().first)
        #expect(request.bodyWasStreamed)
        #expect(request.body?.count ?? 0 > archive.count)
        #expect(request.contentLength == request.body?.count)
        let boundary = try boundary(from: request.contentType)
        let stagingIdentifier = String(boundary.dropFirst("CoderPadKit-".count))
        let stagingFolder = MultipartFormData.stagingRoot
            .appending(path: stagingIdentifier, directoryHint: .isDirectory)
        #expect(!FileManager.default.fileExists(atPath: stagingFolder.path))
    }

    private func makeClient() -> CoderPadClient {
        ZIPCaptureURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ZIPCaptureURLProtocol.self]
        return CoderPadClient(
            apiKey: "test-key",
            baseURL: URL(string: "https://example.com")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func boundary(from contentType: String?) throws -> String {
        let prefix = "multipart/form-data; boundary="
        let contentType = try #require(contentType)
        #expect(contentType.hasPrefix(prefix))
        return String(contentType.dropFirst(prefix.count))
    }

    private func multipartBody(
        boundary: String,
        fields: [(String, String)],
        escapedFilename: String,
        filenameStar: String? = nil,
        fileData: Data
    ) -> Data {
        var result = Data()
        for (name, value) in fields {
            result.append(Data("--\(boundary)\r\n".utf8))
            result.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            result.append(Data(value.utf8))
            result.append(Data("\r\n".utf8))
        }
        result.append(Data("--\(boundary)\r\n".utf8))
        var disposition =
            "Content-Disposition: form-data; name=\"question[zip_file]\"; "
            + "filename=\"\(escapedFilename)\""
        if let filenameStar {
            disposition += "; filename*=UTF-8''\(filenameStar)"
        }
        disposition += "\r\nContent-Type: application/zip\r\n\r\n"
        result.append(Data(disposition.utf8))
        result.append(fileData)
        result.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return result
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}

}

private nonisolated struct CapturedZIPRequest: Sendable {
    let method: String
    let path: String
    let authorization: String?
    let accept: String?
    let contentType: String?
    let contentLength: Int?
    let bodyWasStreamed: Bool
    let body: Data?
}

private final nonisolated class ZIPCaptureURLProtocol: URLProtocol {
    private static let captured = Mutex<[CapturedZIPRequest]>([])

    static func reset() {
        captured.withLock { $0.removeAll() }
    }

    static func requests() -> [CapturedZIPRequest] {
        captured.withLock { $0 }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let bodyStream = request.httpBodyStream
        let body = request.httpBody ?? Self.drain(stream: bodyStream)
        Self.captured.withLock {
            $0.append(CapturedZIPRequest(
                method: request.httpMethod ?? "",
                path: url.path,
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                accept: request.value(forHTTPHeaderField: "Accept"),
                contentType: request.value(forHTTPHeaderField: "Content-Type"),
                contentLength: request.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init),
                bodyWasStreamed: request.httpBody == nil && bodyStream != nil,
                body: body
            ))
        }

        let responseBody = request.httpMethod == "PUT"
            ? Data(#"{"status":"OK"}"#.utf8)
            : Data(#"{"id":42,"title":"Captured"}"#.utf8)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
