@testable import CoderPadKit
import Foundation
import Testing

@Suite("Screen redirect policy")
struct ScreenRedirectTests {
    @Test
    func `Screen redirects remain on the authenticated origin`() async throws {
        let origin = URL(string: "https://www.codingame.com/assessment/api/v1.1/tests")!
        let delegate = ScreenRedirectDelegate(requestURL: origin)
        let task = URLSession.shared.dataTask(with: origin)
        defer { task.cancel() }
        let response = try #require(HTTPURLResponse(
            url: origin,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ))
        var crossOrigin = URLRequest(url: URL(string: "https://attacker.example/tests")!)
        crossOrigin.setValue("secret", forHTTPHeaderField: "API-Key")
        let rejected = await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: crossOrigin,
                completionHandler: { continuation.resume(returning: $0) }
            )
        }

        #expect(rejected == nil)
        #expect(ScreenRedirectDelegate.hasSameOrigin(
            origin,
            URL(string: "https://WWW.CODINGAME.COM:443/assessment/api/v1.1/campaigns")!
        ))
        #expect(!ScreenRedirectDelegate.hasSameOrigin(origin, URL(string: "https://attacker.example/tests")!))
        #expect(!ScreenRedirectDelegate.hasSameOrigin(origin, URL(string: "http://www.codingame.com/tests")!))
        #expect(!ScreenRedirectDelegate.hasSameOrigin(origin, URL(string: "https://www.codingame.com:444/tests")!))
    }
}
