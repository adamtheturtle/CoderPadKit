//
//  MockRequestBody.swift
//  CoderPadKitMock
//
//  Shared request-body helpers for the Interview and Screen URLProtocol mocks.
//

import Foundation

nonisolated enum MockRequestBody {
    /// Reads an `InputStream` body through to EOF. Unlike looping on
    /// `hasBytesAvailable` alone, this keeps reading when the stream briefly reports
    /// no bytes before more data arrives — otherwise JSON/multipart bodies are
    /// truncated and handlers report misleading malformed-body errors (#188).
    static func drain(stream: InputStream?) -> Data? {
        guard let stream else { return nil }

        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while true {
            let read = stream.read(buffer, maxLength: size)
            if read < 0 { return nil }
            if read == 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
