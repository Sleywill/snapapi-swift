import XCTest
@testable import SnapAPI

// MARK: - Validation Tests

final class ValidationTests: XCTestCase {

    func testScreenshotRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.screenshot(ScreenshotOptions())
        }
    }

    func testScreenshotAcceptsURL() {
        let opts = ScreenshotOptions(url: "https://example.com")
        XCTAssertNotNil(opts.url)
        XCTAssertNil(opts.html)
    }

    func testScreenshotAcceptsHTML() {
        let opts = ScreenshotOptions(html: "<h1>Hello</h1>")
        XCTAssertNil(opts.url)
        XCTAssertNotNil(opts.html)
    }

    func testScrapeRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.scrape(ScrapeOptions(url: ""))
        }
    }

    func testExtractRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.extract(ExtractOptions(url: ""))
        }
    }

    func testPdfRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.pdf(PdfOptions(url: ""))
        }
    }

    func testVideoRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.video(VideoOptions(url: ""))
        }
    }

    func testVideoResultRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.videoResult(VideoOptions(url: ""))
        }
    }

    func testScreenshotToStorageRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrows(SnapAPIError.invalidParameters("")) {
            _ = try await client.screenshotToStorage(ScreenshotOptions())
        }
    }
}

// MARK: - Error Tests

final class ErrorTests: XCTestCase {

    // MARK: isRetryable

    func testRateLimitedIsRetryable() {
        XCTAssertTrue(SnapAPIError.rateLimited(retryAfter: 30).isRetryable)
    }

    func testNetworkErrorIsRetryable() {
        XCTAssertTrue(SnapAPIError.networkError(URLError(.timedOut)).isRetryable)
    }

    func testServerError5xxIsRetryable() {
        XCTAssertTrue(SnapAPIError.serverError(statusCode: 500, message: "oops").isRetryable)
        XCTAssertTrue(SnapAPIError.serverError(statusCode: 503, message: "down").isRetryable)
    }

    func testServerError4xxNotRetryable() {
        XCTAssertFalse(SnapAPIError.serverError(statusCode: 400, message: "bad").isRetryable)
        XCTAssertFalse(SnapAPIError.serverError(statusCode: 404, message: "nope").isRetryable)
    }

    func testUnauthorizedNotRetryable() {
        XCTAssertFalse(SnapAPIError.unauthorized.isRetryable)
    }

    func testQuotaExceededNotRetryable() {
        XCTAssertFalse(SnapAPIError.quotaExceeded.isRetryable)
    }

    func testInvalidParametersNotRetryable() {
        XCTAssertFalse(SnapAPIError.invalidParameters("url required").isRetryable)
    }

    func testDecodingErrorNotRetryable() {
        XCTAssertFalse(SnapAPIError.decodingError(NSError(domain: "d", code: 1)).isRetryable)
    }

    // MARK: retryAfter

    func testRetryAfterExtracted() {
        let err = SnapAPIError.rateLimited(retryAfter: 45)
        XCTAssertEqual(err.retryAfter, 45)
    }

    func testRetryAfterNilForOtherErrors() {
        XCTAssertNil(SnapAPIError.serverError(statusCode: 500, message: "").retryAfter)
        XCTAssertNil(SnapAPIError.unauthorized.retryAfter)
    }

    // MARK: errorDescription

    func testUnauthorizedDescription() {
        XCTAssertTrue(SnapAPIError.unauthorized.errorDescription!.contains("Unauthorized"))
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
        let desc = SnapAPIError.networkError(URLError(.notConnectedToInternet)).errorDescription!
        XCTAssertTrue(desc.contains("Network error"))
    }

    func testInvalidParametersDescription() {
        let desc = SnapAPIError.invalidParameters("url is required").errorDescription!
        XCTAssertTrue(desc.contains("url is required"))
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
}

// MARK: - RetryPolicy Tests

final class RetryPolicyTests: XCTestCase {

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
        // delay1 should be ~2x delay0
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
}

// MARK: - Model Tests

final class ModelTests: XCTestCase {

    func testScreenshotFormatRawValues() {
        XCTAssertEqual(ScreenshotFormat.png.rawValue,  "png")
        XCTAssertEqual(ScreenshotFormat.jpeg.rawValue, "jpeg")
        XCTAssertEqual(ScreenshotFormat.pdf.rawValue,  "pdf")
    }

    func testExtractFormatRawValues() {
        XCTAssertEqual(ExtractFormat.markdown.rawValue, "markdown")
        XCTAssertEqual(ExtractFormat.article.rawValue,  "article")
    }

    func testVideoFormatRawValues() {
        XCTAssertEqual(VideoFormat.mp4.rawValue,  "mp4")
        XCTAssertEqual(VideoFormat.webm.rawValue, "webm")
        XCTAssertEqual(VideoFormat.gif.rawValue,  "gif")
    }

    func testAnyCodableString() throws {
        let json = #"{"key":"hello"}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(d["key"]?.value as? String, "hello")
    }

    func testAnyCodableInt() throws {
        let json = #"{"n":42}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(d["n"]?.value as? Int, 42)
    }

    func testAnyCodableBool() throws {
        let json = #"{"flag":true}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(d["flag"]?.value as? Bool, true)
    }

    func testAnyCodableNull() throws {
        let json = #"{"x":null}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertNotNil(d["x"])
    }

    func testSnapCookieInit() {
        let c = SnapCookie(name: "session", value: "abc123", domain: ".example.com")
        XCTAssertEqual(c.name,   "session")
        XCTAssertEqual(c.value,  "abc123")
        XCTAssertEqual(c.domain, ".example.com")
        XCTAssertNil(c.path)
    }

    func testGeolocationInit() {
        let g = Geolocation(latitude: 51.5, longitude: -0.1, accuracy: 10)
        XCTAssertEqual(g.latitude,  51.5)
        XCTAssertEqual(g.longitude, -0.1)
        XCTAssertEqual(g.accuracy,  10)
    }
}

// MARK: - HTTP Tests (using mock URLSession)

final class HTTPClientTests: XCTestCase {

    func testUnauthorizedResponseThrowsUnauthorized() async throws {
        let session = MockURLSession(statusCode: 401, data: Data())
        let client = SnapAPIClient(
            apiKey: "bad-key",
            session: session,
            retryPolicy: .never
        )
        do {
            _ = try await client.quota()
            XCTFail("Expected unauthorized error")
        } catch SnapAPIError.unauthorized {
            // pass
        }
    }

    func testQuotaExceededResponse() async throws {
        let session = MockURLSession(statusCode: 402, data: Data())
        let client = SnapAPIClient(
            apiKey: "sk_test",
            session: session,
            retryPolicy: .never
        )
        do {
            _ = try await client.quota()
            XCTFail("Expected quotaExceeded error")
        } catch SnapAPIError.quotaExceeded {
            // pass
        }
    }

    func testRateLimitedResponseWith429() async throws {
        let session = MockURLSession(
            statusCode: 429,
            data: Data(),
            headers: ["Retry-After": "30"]
        )
        let client = SnapAPIClient(
            apiKey: "sk_test",
            session: session,
            retryPolicy: .never
        )
        do {
            _ = try await client.quota()
            XCTFail("Expected rateLimited error")
        } catch SnapAPIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 30)
        }
    }

    func testServerErrorResponse() async throws {
        let body = #"{"error":"INTERNAL_ERROR","message":"Something went wrong"}"#
            .data(using: .utf8)!
        let session = MockURLSession(statusCode: 500, data: body)
        let client = SnapAPIClient(
            apiKey: "sk_test",
            session: session,
            retryPolicy: .never
        )
        do {
            _ = try await client.quota()
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 500)
            XCTAssertTrue(msg.contains("Something went wrong"))
        }
    }

    func testSuccessfulQuotaDecoding() async throws {
        let body = #"{"used":120,"total":1000,"remaining":880}"#.data(using: .utf8)!
        let session = MockURLSession(statusCode: 200, data: body)
        let client = SnapAPIClient(apiKey: "sk_test", session: session, retryPolicy: .never)
        let quota = try await client.quota()
        XCTAssertEqual(quota.used,      120)
        XCTAssertEqual(quota.total,     1000)
        XCTAssertEqual(quota.remaining, 880)
    }

    func testSuccessfulScreenshot() async throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let session = MockURLSession(statusCode: 200, data: imageBytes)
        let client = SnapAPIClient(apiKey: "sk_test", session: session, retryPolicy: .never)
        let result = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
        XCTAssertEqual(result, imageBytes)
    }
}

// MARK: - Mock URLSession

/// A `URLSession` subclass that returns pre-canned responses for testing.
final class MockURLSession: URLSession, @unchecked Sendable {

    private let statusCode: Int
    private let data: Data
    private let headers: [String: String]

    init(statusCode: Int, data: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.data       = data
        self.headers    = headers
        // URLSession.init() is not available to subclass directly in test targets.
        // We call the designated initialiser with a default configuration.
        super.init(configuration: .ephemeral)
    }

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        return (data, response)
    }
}

// MARK: - Helpers

/// Asserts that the closure throws a ``SnapAPIError`` with the expected case.
private func assertThrows<T>(
    _ expected: SnapAPIError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> T
) async {
    do {
        _ = try await body()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch let err as SnapAPIError {
        // Compare case names (not associated values) via string description
        let got = "\(err)"
        let exp = "\(expected)"
        // Only compare the leading case label (before first parenthesis)
        let gotLabel = got.prefix(while: { $0 != "(" })
        let expLabel = exp.prefix(while: { $0 != "(" })
        XCTAssertEqual(String(gotLabel), String(expLabel), file: file, line: line)
    } catch {
        XCTFail("Expected SnapAPIError but got \(error)", file: file, line: line)
    }
}
