import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Error Tests

final class SnapAPIErrorTests: XCTestCase {

    // MARK: isRetryable

    func testRateLimitedIsRetryable() {
        XCTAssertTrue(SnapAPIError.rateLimited(retryAfter: 30).isRetryable)
    }

    func testNetworkErrorIsRetryable() {
        XCTAssertTrue(SnapAPIError.networkError(underlying: URLError(.timedOut)).isRetryable)
    }

    func testServerError5xxIsRetryable() {
        XCTAssertTrue(SnapAPIError.serverError(statusCode: 500, message: "oops").isRetryable)
        XCTAssertTrue(SnapAPIError.serverError(statusCode: 503, message: "down").isRetryable)
    }

    func testServerError4xxNotRetryable() {
        XCTAssertFalse(SnapAPIError.serverError(statusCode: 400, message: "bad").isRetryable)
        XCTAssertFalse(SnapAPIError.serverError(statusCode: 404, message: "nope").isRetryable)
    }

    func testAuthenticationFailedNotRetryable() {
        XCTAssertFalse(SnapAPIError.authenticationFailed.isRetryable)
    }

    func testQuotaExceededNotRetryable() {
        XCTAssertFalse(SnapAPIError.quotaExceeded.isRetryable)
    }

    func testInvalidParametersNotRetryable() {
        XCTAssertFalse(SnapAPIError.invalidParameters("url required").isRetryable)
    }

    func testDecodingErrorNotRetryable() {
        XCTAssertFalse(SnapAPIError.decodingError(underlying: NSError(domain: "d", code: 1)).isRetryable)
    }

    // MARK: retryAfter

    func testRetryAfterExtracted() {
        let err = SnapAPIError.rateLimited(retryAfter: 45)
        XCTAssertEqual(err.retryAfter, 45)
    }

    func testRetryAfterNilForOtherErrors() {
        XCTAssertNil(SnapAPIError.serverError(statusCode: 500, message: "").retryAfter)
        XCTAssertNil(SnapAPIError.authenticationFailed.retryAfter)
    }

    // MARK: errorDescription (LocalizedError)

    func testAuthenticationFailedDescription() {
        XCTAssertTrue(SnapAPIError.authenticationFailed.errorDescription!.contains("Authentication"))
    }

    func testRateLimitedDescription() {
        let desc = SnapAPIError.rateLimited(retryAfter: 60).errorDescription!
        XCTAssertTrue(desc.contains("Rate limited"))
        XCTAssertTrue(desc.contains("60"))
    }

    func testQuotaExceededDescription() {
        XCTAssertTrue(SnapAPIError.quotaExceeded.errorDescription!.contains("Quota exceeded"))
    }

    func testServerErrorDescription() {
        let desc = SnapAPIError.serverError(statusCode: 503, message: "Service Unavailable").errorDescription!
        XCTAssertTrue(desc.contains("503"))
        XCTAssertTrue(desc.contains("Service Unavailable"))
    }

    func testNetworkErrorDescription() {
        let desc = SnapAPIError.networkError(underlying: URLError(.notConnectedToInternet)).errorDescription!
        XCTAssertTrue(desc.contains("Network error"))
    }

    func testInvalidParametersDescription() {
        let desc = SnapAPIError.invalidParameters("url is required").errorDescription!
        XCTAssertTrue(desc.contains("url is required"))
    }

    func testDecodingErrorDescription() {
        let desc = SnapAPIError.decodingError(underlying: NSError(domain: "test", code: 1)).errorDescription!
        XCTAssertTrue(desc.contains("Decoding error"))
    }

    // MARK: Pattern matching

    func testPatternMatchRateLimited() {
        let err: SnapAPIError = .rateLimited(retryAfter: 10)
        if case .rateLimited(let t) = err {
            XCTAssertEqual(t, 10)
        } else {
            XCTFail("Expected .rateLimited")
        }
    }

    func testPatternMatchServerError() {
        let err: SnapAPIError = .serverError(statusCode: 422, message: "Unprocessable")
        if case .serverError(let code, let msg) = err {
            XCTAssertEqual(code, 422)
            XCTAssertEqual(msg, "Unprocessable")
        } else {
            XCTFail("Expected .serverError")
        }
    }

    // MARK: HTTP status mapping

    func testUnauthorizedMapsToAuthenticationFailed() async throws {
        let client = makeClient(response: MockResponse(statusCode: 401, data: Data()))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected authenticationFailed error")
        } catch SnapAPIError.authenticationFailed {
            // pass
        }
    }

    func testForbiddenMapsToAuthenticationFailed() async throws {
        let client = makeClient(response: MockResponse(statusCode: 403, data: Data()))
        do {
            _ = try await client.ping()
            XCTFail("Expected authenticationFailed error")
        } catch SnapAPIError.authenticationFailed {
            // pass
        }
    }

    func testQuotaExceededResponse() async throws {
        let client = makeClient(response: MockResponse(statusCode: 402, data: Data()))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected quotaExceeded error")
        } catch SnapAPIError.quotaExceeded {
            // pass
        }
    }

    func testDecodingErrorOnMalformedJSON() async throws {
        let body = "not json at all".data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected decodingError")
        } catch SnapAPIError.decodingError {
            // pass
        }
    }

    // MARK: - Retry Policy

    func testDefaultPolicyAllowsThreeRetries() {
        let policy = RetryPolicy.default
        XCTAssertTrue(policy.shouldRetry(error: .rateLimited(retryAfter: 1), attempt: 0))
        XCTAssertTrue(policy.shouldRetry(error: .rateLimited(retryAfter: 1), attempt: 2))
        XCTAssertFalse(policy.shouldRetry(error: .rateLimited(retryAfter: 1), attempt: 3))
    }

    func testNeverPolicyNeverRetries() {
        let policy = RetryPolicy.never
        XCTAssertFalse(policy.shouldRetry(error: .rateLimited(retryAfter: 1), attempt: 0))
    }

    func testExponentialBackoff() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1.0, maxDelay: 30.0)
        let delay0 = policy.delay(forAttempt: 0)
        let delay1 = policy.delay(forAttempt: 1)
        XCTAssertGreaterThan(delay1, delay0)
    }

    func testRetryAfterOverride() {
        let policy = RetryPolicy()
        let ns = policy.delay(forAttempt: 0, overrideSeconds: 10)
        XCTAssertEqual(ns, UInt64(10_000_000_000))
    }

    func testMaxDelayCapIsRespected() {
        let policy = RetryPolicy(maxAttempts: 10, baseDelay: 1.0, maxDelay: 5.0)
        let ns = policy.delay(forAttempt: 9) // would be 512s without cap
        let seconds = Double(ns) / 1_000_000_000
        XCTAssertLessThanOrEqual(seconds, 5.0 + 0.001)
    }

    // MARK: - Retry integration

    func testRetryOnNetworkFailure() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailOnceURLProtocol.self]
        FailOnceURLProtocol.callCount = 0
        let successBody = #"{"used":5,"limit":100,"remaining":95}"#.data(using: .utf8)!
        FailOnceURLProtocol.successResponse = MockResponse(statusCode: 200, data: successBody)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 0.001, maxDelay: 0.001)
        )
        let usage = try await client.getUsage()
        XCTAssertEqual(usage.used, 5)
        XCTAssertEqual(FailOnceURLProtocol.callCount, 2)
    }

    // MARK: - Helpers

    private func makeClient(response: MockResponse) -> SnapAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.response = response
        let session = URLSession(configuration: config)
        return SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
    }
}
