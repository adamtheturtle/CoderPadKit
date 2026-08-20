//
//  ScreenClient+ResponseData.swift
//  CoderPadKit
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

nonisolated extension ScreenClient {
    /// Runs a bounded request, mapping transport and HTTP failures onto CoderPadError.
    @discardableResult
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #if canImport(FoundationNetworking)
            // Stream with an enforced ceiling so a large 2xx body cannot allocate past
            // ``maximumResponseBodyBytes`` before the check runs (#205).
            let (data, http) = try await ScreenBoundedResponseLoader(
                successLimit: maximumResponseBodyBytes,
                errorLimit: Self.maximumErrorBodyBytes,
                requestURL: request.url
            ).load(
                configuration: session.configuration,
                delegateQueue: session.delegateQueue,
                request: request
            )
            guard (200 ..< 300).contains(http.statusCode) else {
                throw CoderPadError.http(http.statusCode, String(bytes: data, encoding: .utf8) ?? "")
            }
            return (data, http)
        #else
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(
                for: request,
                delegate: ScreenRedirectDelegate(requestURL: request.url)
            )
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        }
        let (http, limit) = try responseMetadata(for: response)
        let isSuccess = (200 ..< 300).contains(http.statusCode)

        let data = try await responseBody(from: bytes, response: http, limit: limit, isSuccess: isSuccess)
        guard isSuccess else {
            throw CoderPadError.http(http.statusCode, String(bytes: data, encoding: .utf8) ?? "")
        }
        return (data, http)
        #endif
    }

    #if !canImport(FoundationNetworking)
    private func responseBody(
        from bytes: URLSession.AsyncBytes,
        response: HTTPURLResponse,
        limit: Int,
        isSuccess: Bool
    ) async throws -> Data {
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(response.expectedContentLength), limit))
        }
        do {
            for try await byte in bytes {
                guard data.count < limit else {
                    if isSuccess {
                        throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
                    }
                    break
                }
                data.append(byte)
            }
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        }
        return data
    }

    private func responseMetadata(for response: URLResponse) throws -> (HTTPURLResponse, Int) {
        guard let http = response as? HTTPURLResponse else {
            throw CoderPadError.http(0, "No HTTP response")
        }
        let isSuccess = (200 ..< 300).contains(http.statusCode)
        let limit = isSuccess ? maximumResponseBodyBytes : Self.maximumErrorBodyBytes
        if isSuccess, http.expectedContentLength > Int64(limit) {
            throw CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
        }
        return (http, limit)
    }
    #endif
}

#if canImport(FoundationNetworking)
/// Incrementally accumulates a Screen response and cancels once the applicable byte
/// ceiling is exceeded, so success bodies cannot bypass ``maximumResponseBodyBytes``.
final class ScreenBoundedResponseLoader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct State {
        var continuation: CheckedContinuation<(Data, HTTPURLResponse), any Error>?
        var session: URLSession?
        var task: URLSessionDataTask?
        var response: HTTPURLResponse?
        var data = Data()
        var limit = 0
        var completed = false
        var cancelled = false
    }

    private enum Receipt {
        case ignored
        case accepted
        case overflow(CoderPadError)
    }

    private let lock = NSLock()
    private var state = State()
    private let successLimit: Int
    private let errorLimit: Int
    private let redirectDelegate: ScreenRedirectDelegate

    init(successLimit: Int, errorLimit: Int, requestURL: URL?) {
        self.successLimit = successLimit
        self.errorLimit = errorLimit
        redirectDelegate = ScreenRedirectDelegate(requestURL: requestURL)
    }

    func load(
        configuration: URLSessionConfiguration,
        delegateQueue: OperationQueue,
        request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let task = lock.withLock { () -> URLSessionDataTask? in
                        guard !state.cancelled else { return nil }
                        let session = URLSession(
                            configuration: configuration,
                            delegate: self,
                            delegateQueue: delegateQueue
                        )
                        let task = session.dataTask(with: request)
                        state.continuation = continuation
                        state.session = session
                        state.task = task
                        return task
                    }
                    guard let task else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    task.resume()
                }
            } onCancel: {
                cancel()
            }
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw CancellationError() }
            throw CoderPadError.network(urlError)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            complete(.failure(CoderPadError.http(0, "No HTTP response")))
            return
        }
        let isSuccess = (200 ..< 300).contains(http.statusCode)
        let limit = isSuccess ? successLimit : errorLimit
        if isSuccess, http.expectedContentLength > Int64(limit) {
            completionHandler(.cancel)
            complete(.failure(
                CoderPadError.decode("The Screen response exceeded the \(limit)-byte limit.")
            ))
            return
        }

        lock.withLock {
            guard !state.completed else { return }
            state.response = http
            state.limit = limit
            if http.expectedContentLength > 0 {
                state.data.reserveCapacity(min(Int(http.expectedContentLength), limit))
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let receipt = lock.withLock { () -> Receipt in
            guard !state.completed, let response = state.response else { return .ignored }
            let isSuccess = (200 ..< 300).contains(response.statusCode)
            guard data.count <= state.limit - state.data.count else {
                if isSuccess {
                    return .overflow(
                        CoderPadError.decode("The Screen response exceeded the \(state.limit)-byte limit.")
                    )
                }
                let remaining = state.limit - state.data.count
                if remaining > 0 {
                    state.data.append(data.prefix(remaining))
                }
                dataTask.cancel()
                return .overflow(CoderPadError.http(
                    response.statusCode,
                    String(bytes: state.data, encoding: .utf8) ?? ""
                ))
            }
            state.data.append(data)
            return .accepted
        }
        switch receipt {
        case .ignored, .accepted:
            break
        case let .overflow(error):
            dataTask.cancel()
            complete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            if (error as? URLError)?.code == .cancelled,
               let http = lock.withLock({ state.response }),
               !(200 ..< 300).contains(http.statusCode) {
                // Truncated after reaching the error-body ceiling — surface the HTTP error.
                let body = lock.withLock { state.data }
                complete(.failure(CoderPadError.http(
                    http.statusCode,
                    String(bytes: body, encoding: .utf8) ?? ""
                )))
                return
            }
            complete(.failure(error))
            return
        }
        let result = lock.withLock { () -> (Data, HTTPURLResponse)? in
            guard let response = state.response else { return nil }
            return (state.data, response)
        }
        complete(result.map(Result.success) ?? .failure(CoderPadError.http(0, "No HTTP response")))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        redirectDelegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: request,
            completionHandler: completionHandler
        )
    }

    private struct CancellationResources {
        let continuation: CheckedContinuation<(Data, HTTPURLResponse), any Error>?
        let task: URLSessionDataTask?
        let session: URLSession?
    }

    private func cancel() {
        let resources = lock.withLock { () -> CancellationResources in
            state.cancelled = true
            guard !state.completed else {
                return CancellationResources(continuation: nil, task: nil, session: nil)
            }
            state.completed = true
            let result = CancellationResources(
                continuation: state.continuation,
                task: state.task,
                session: state.session
            )
            state.continuation = nil
            state.task = nil
            state.session = nil
            return result
        }
        resources.task?.cancel()
        resources.session?.invalidateAndCancel()
        resources.continuation?.resume(throwing: CancellationError())
    }

    private func complete(_ result: Result<(Data, HTTPURLResponse), any Error>) {
        let resources = lock.withLock { () -> (CheckedContinuation<(Data, HTTPURLResponse), any Error>?,
                                               URLSession?) in
            guard !state.completed else { return (nil, nil) }
            state.completed = true
            let pair = (state.continuation, state.session)
            state.continuation = nil
            state.task = nil
            state.session = nil
            return pair
        }
        resources.1?.finishTasksAndInvalidate()
        resources.0?.resume(with: result)
    }
}
#endif
