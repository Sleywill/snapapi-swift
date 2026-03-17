import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Validation Tests

final class ValidationTests: XCTestCase {

    func testScreenshotRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
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
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.scrape(ScrapeOptions(url: ""))
        }
    }

    func testExtractRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.extract(ExtractOptions(url: ""))
        }
    }

    func testPdfRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.pdf(PdfOptions(url: ""))
        }
    }

    func testVideoRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.video(VideoOptions(url: ""))
        }
    }

    func testVideoResultRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.videoResult(VideoOptions(url: ""))
        }
    }

    func testScreenshotToStorageRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.screenshotToStorage(ScreenshotOptions())
        }
    }

    func testAnalyzeRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        await assertThrowsSnapAPIError(.invalidParameters("")) {
            _ = try await client.analyze(AnalyzeOptions(url: ""))
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

    // MARK: errorDescription

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

    func testAnalyzeProviderRawValues() {
        XCTAssertEqual(AnalyzeProvider.openai.rawValue,    "openai")
        XCTAssertEqual(AnalyzeProvider.anthropic.rawValue, "anthropic")
        XCTAssertEqual(AnalyzeProvider.google.rawValue,    "google")
    }

    // MARK: AnyCodable

    func testAnyCodableStringRoundTrip() throws {
        let json = #"{"key":"hello"}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .string(let s) = d["key"]?.value else {
            XCTFail("Expected .string AnyJSON")
            return
        }
        XCTAssertEqual(s, "hello")
    }

    func testAnyCodableIntRoundTrip() throws {
        let json = #"{"n":42}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .int(let i) = d["n"]?.value else {
            XCTFail("Expected .int AnyJSON")
            return
        }
        XCTAssertEqual(i, 42)
    }

    func testAnyCodableBoolRoundTrip() throws {
        let json = #"{"flag":true}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .bool(let b) = d["flag"]?.value else {
            XCTFail("Expected .bool AnyJSON")
            return
        }
        XCTAssertTrue(b)
    }

    func testAnyCodableNull() throws {
        let json = #"{"x":null}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertNotNil(d["x"])
        if let val = d["x"] {
            XCTAssertEqual(val.value, .null)
        }
    }

    func testAnyCodableEncodeDecodeRoundTrip() throws {
        let original: AnyCodable = ["name": "Alice", "age": 30, "active": true]
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testAnyCodableLiterals() {
        let str: AnyCodable = "hello"
        let num: AnyCodable = 42
        let flag: AnyCodable = true
        let nothing: AnyCodable = nil

        XCTAssertEqual(str.value, .string("hello"))
        XCTAssertEqual(num.value, .int(42))
        XCTAssertEqual(flag.value, .bool(true))
        XCTAssertEqual(nothing.value, .null)
    }

    func testAnyCodableDynamicMemberLookup() throws {
        let json = #"{"user":{"name":"Bob"}}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode(AnyCodable.self, from: json)
        guard case .string(let name) = d.user?.name?.value else {
            XCTFail("Dynamic member lookup failed")
            return
        }
        XCTAssertEqual(name, "Bob")
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

    func testAnalyzeOptionsInit() {
        var opts = AnalyzeOptions(url: "https://example.com")
        opts.prompt   = "Summarize"
        opts.provider = .openai
        XCTAssertEqual(opts.url, "https://example.com")
        XCTAssertEqual(opts.prompt, "Summarize")
        XCTAssertEqual(opts.provider, .openai)
    }

    func testVideoOptionsFullPage() {
        var opts = VideoOptions(url: "https://example.com")
        opts.fullPage = true
        XCTAssertEqual(opts.fullPage, true)
    }

    func testPDFPageOptionsInit() {
        let opts = PDFPageOptions(
            pageSize: .a4,
            landscape: true,
            marginTop: "1cm",
            marginRight: "1cm",
            marginBottom: "1cm",
            marginLeft: "1cm"
        )
        XCTAssertEqual(opts.pageSize, .a4)
        XCTAssertEqual(opts.landscape, true)
        XCTAssertEqual(opts.marginTop, "1cm")
    }

    func testScreenshotOptionsEncoding() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.fullPage = true
        opts.darkMode = true
        opts.format = .jpeg
        opts.width = 1280
        opts.blockAds = true

        let data = try JSONEncoder.snapAPI.encode(opts)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        // The encoder uses snake_case — verify keys
        XCTAssertNotNil(json["full_page"])
        XCTAssertNotNil(json["dark_mode"])
        XCTAssertNotNil(json["block_ads"])
    }

    func testScrapeOptionsEncoding() throws {
        var opts = ScrapeOptions(url: "https://example.com")
        opts.selector = "article"
        opts.wait = 500
        opts.pages = 3

        let data = try JSONEncoder.snapAPI.encode(opts)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        XCTAssertNotNil(json["url"])
        XCTAssertNotNil(json["selector"])
        XCTAssertNotNil(json["wait"])
        XCTAssertNotNil(json["pages"])
    }

    func testExtractFormatAllCases() {
        let allFormats: [ExtractFormat] = [
            .markdown, .text, .html, .article, .links, .images, .metadata, .structured
        ]
        XCTAssertEqual(ExtractFormat.allCases.count, allFormats.count)
    }
}

// MARK: - HTTP Tests (using URLProtocol mock)

final class HTTPClientTests: XCTestCase {

    private func makeClient(response: MockResponse, retryPolicy: RetryPolicy = .never) -> SnapAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.response = response
        let session = URLSession(configuration: config)
        return SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: retryPolicy
        )
    }

    func testUnauthorizedResponseThrowsAuthenticationFailed() async throws {
        let client = makeClient(response: MockResponse(statusCode: 401, data: Data()))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected authenticationFailed error")
        } catch SnapAPIError.authenticationFailed {
            // pass
        }
    }

    func testForbiddenResponseThrowsAuthenticationFailed() async throws {
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

    func testRateLimitedResponseWith429() async throws {
        let client = makeClient(response: MockResponse(
            statusCode: 429,
            data: Data(),
            headers: ["Retry-After": "30"]
        ))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected rateLimited error")
        } catch SnapAPIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 30)
        }
    }

    func testServerErrorResponse() async throws {
        let body = #"{"error":"INTERNAL_ERROR","message":"Something went wrong"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 500, data: body))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 500)
            XCTAssertTrue(msg.contains("Something went wrong"))
        }
    }

    func testSuccessfulUsageDecoding() async throws {
        let body = #"{"used":120,"total":1000,"remaining":880}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let usage = try await client.getUsage()
        XCTAssertEqual(usage.used,      120)
        XCTAssertEqual(usage.total,     1000)
        XCTAssertEqual(usage.remaining, 880)
    }

    func testSuccessfulQuotaDecoding() async throws {
        let body = #"{"used":50,"total":500,"remaining":450}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let quota = try await client.quota()
        XCTAssertEqual(quota.used, 50)
        XCTAssertEqual(quota.remaining, 450)
    }

    func testSuccessfulScreenshot() async throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        let client = makeClient(response: MockResponse(statusCode: 200, data: imageBytes))
        let result = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
        XCTAssertEqual(result, imageBytes)
    }

    func testSuccessfulPing() async throws {
        let body = #"{"status":"ok","timestamp":1710000000000}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let ping = try await client.ping()
        XCTAssertEqual(ping.status, "ok")
        XCTAssertEqual(ping.timestamp, 1_710_000_000_000)
    }

    func testSuccessfulScrape() async throws {
        let body = #"{"success":true,"results":[{"page":1,"url":"https://example.com","data":"hello"}]}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let result = try await client.scrape(ScrapeOptions(url: "https://example.com"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].page, 1)
        XCTAssertEqual(result.results[0].data, "hello")
    }

    func testSuccessfulExtract() async throws {
        // Use string concatenation to avoid raw-string delimiter conflicts
        let bodyStr = "{\"success\":true,\"type\":\"markdown\",\"url\":\"https://example.com\",\"data\":\"Hello\",\"response_time\":250}"
        let body = bodyStr.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let result = try await client.extract(ExtractOptions(url: "https://example.com"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.type, "markdown")
        XCTAssertEqual(result.responseTime, 250)
    }

    func testAnalyze503ReturnsServerError() async throws {
        let body = #"{"error":"SERVICE_UNAVAILABLE","message":"LLM credits exhausted"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 503, data: body))
        do {
            _ = try await client.analyze(AnalyzeOptions(url: "https://example.com"))
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 503)
            XCTAssertTrue(msg.contains("LLM credits exhausted"))
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

    func testXApiKeyHeaderIsSent() async throws {
        let body = #"{"used":1,"total":100,"remaining":99}"#.data(using: .utf8)!
        // Use a custom URLProtocol that inspects the request header
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HeaderCapturingURLProtocol.self]
        HeaderCapturingURLProtocol.response = MockResponse(statusCode: 200, data: body)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_test_header_check",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        _ = try await client.getUsage()
        XCTAssertEqual(HeaderCapturingURLProtocol.capturedAPIKey, "sk_test_header_check")
    }

    func testAuthorizationBearerHeaderIsSent() async throws {
        let body = #"{"used":1,"total":100,"remaining":99}"#.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HeaderCapturingURLProtocol.self]
        HeaderCapturingURLProtocol.response = MockResponse(statusCode: 200, data: body)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_bearer_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        _ = try await client.getUsage()
        XCTAssertEqual(HeaderCapturingURLProtocol.capturedAuthHeader, "Bearer sk_bearer_test")
    }

    func testRetryOnNetworkFailure() async throws {
        // Switch to failure protocol after first attempt
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailOnceURLProtocol.self]
        FailOnceURLProtocol.callCount = 0
        let successBody = #"{"used":5,"total":100,"remaining":95}"#.data(using: .utf8)!
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
}

// MARK: - Request Builder Tests

final class RequestBuilderTests: XCTestCase {

    private let builder = RequestBuilder(
        baseURL: URL(string: "https://api.snapapi.pics")!,
        apiKey: "sk_test_builder"
    )

    func testGetRequestMethod() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.httpMethod, "GET")
    }

    func testPostRequestMethod() throws {
        struct Empty: Encodable {}
        let req = try builder.post(path: "/v1/screenshot", body: Empty())
        XCTAssertEqual(req.httpMethod, "POST")
    }

    func testDeleteRequestMethod() {
        let req = builder.delete(path: "/v1/something")
        XCTAssertEqual(req.httpMethod, "DELETE")
    }

    func testBaseURLComposedCorrectly() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.url?.absoluteString, "https://api.snapapi.pics/v1/ping")
    }

    func testApiKeyHeaderSet() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Api-Key"), "sk_test_builder")
    }

    func testAuthorizationHeaderSet() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk_test_builder")
    }

    func testContentTypeSetOnPost() throws {
        struct Empty: Encodable {}
        let req = try builder.post(path: "/v1/screenshot", body: Empty())
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testTimeoutInterval() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.timeoutInterval, 120)
    }

    func testUserAgentHeader() {
        let req = builder.get(path: "/v1/ping")
        let ua = req.value(forHTTPHeaderField: "User-Agent")
        XCTAssertNotNil(ua)
        XCTAssertTrue(ua!.hasPrefix("snapapi-swift/"))
    }
}

// MARK: - MockURLProtocol

/// Canned-response mock using URLProtocol — works with async/await and actors.
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

/// URLProtocol that fails on the first call and succeeds on subsequent calls.
final class FailOnceURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var callCount: Int = 0
    nonisolated(unsafe) static var successResponse: MockResponse = MockResponse(statusCode: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.callCount += 1
        if Self.callCount == 1 {
            // Fail the first attempt with a network error
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

// MARK: - Helpers

/// Asserts that the closure throws a ``SnapAPIError`` matching the expected case label.
private func assertThrowsSnapAPIError<T>(
    _ expected: SnapAPIError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> T
) async {
    do {
        _ = try await body()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch let err as SnapAPIError {
        // Compare case names only (ignore associated values)
        let gotLabel = "\(err)".prefix(while: { $0 != "(" })
        let expLabel = "\(expected)".prefix(while: { $0 != "(" })
        XCTAssertEqual(String(gotLabel), String(expLabel), file: file, line: line)
    } catch {
        XCTFail("Expected SnapAPIError but got \(error)", file: file, line: line)
    }
}
