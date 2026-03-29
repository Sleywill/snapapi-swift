import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - MockResponse

/// Canned-response mock using URLProtocol -- works with async/await and actors.
struct MockResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    init(statusCode: Int, data: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.data       = data
        self.headers    = headers
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    // nonisolated(unsafe) so tests can set this from synchronous code
    nonisolated(unsafe) static var response: MockResponse = MockResponse(statusCode: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let r = Self.response
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: r.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: r.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: r.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - HeaderCapturingURLProtocol

/// URLProtocol that captures headers for inspection.
final class HeaderCapturingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: MockResponse = MockResponse(statusCode: 200, data: Data())
    nonisolated(unsafe) static var capturedAPIKey: String? = nil
    nonisolated(unsafe) static var capturedAuthHeader: String? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedAPIKey    = request.value(forHTTPHeaderField: "X-Api-Key")
        Self.capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")

        let r = Self.response
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: r.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: r.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: r.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - FailOnceURLProtocol

/// URLProtocol that fails on the first call and succeeds on subsequent calls.
final class FailOnceURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var callCount: Int = 0
    nonisolated(unsafe) static var successResponse: MockResponse = MockResponse(statusCode: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.callCount += 1
        if Self.callCount == 1 {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
        } else {
            let r = Self.successResponse
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: r.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: r.data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
