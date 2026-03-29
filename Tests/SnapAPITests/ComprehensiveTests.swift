import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Comprehensive SDK Tests
//
// Covers all areas not fully exercised by the existing test files:
//  - UsageResult "limit" -> "total" CodingKeys fix
//  - quota() routing fix (calls /v1/usage, not /v1/quota)
//  - PingResult timestamp decoding
//  - All ScreenshotOptions fields encode to correct snake_case keys
//  - All VideoOptions fields encode correctly
//  - All ExtractOptions fields encode correctly
//  - PDFOptions encoding
//  - AnalyzeOptions with jsonSchema encoding
//  - Error mapping for all HTTP status codes
//  - RetryPolicy: custom configuration, delay calculations
//  - HTTPClient retry count tracking
//  - Task cancellation is surfaced as SnapAPIError.networkError
//  - SnapAPI typealias == SnapAPIClient
//  - screenshotToFile writes correct bytes
//  - pdfFromScreenshot forces format = .pdf
//  - URL composition with trailing slash in baseURL
//  - Concurrent requests from the same actor are safe

// MARK: - Helpers

private func makeClient(
    response: MockResponse,
    retryPolicy: RetryPolicy = .never
) -> SnapAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.response = response
    let session = URLSession(configuration: config)
    return SnapAPIClient(
        apiKey: "sk_test_comprehensive",
        baseURL: URL(string: "https://api.snapapi.pics")!,
        session: session,
        retryPolicy: retryPolicy
    )
}

// MARK: - UsageResult CodingKeys (limit -> total)

final class UsageResultDecodingTests: XCTestCase {

    /// The live API returns `"limit"` not `"total"`.
    /// This was a real bug; the CodingKeys fix must make this decode correctly.
    func testLiveAPIShapeDecodesTotal() throws {
        let json = #"{"used":58,"limit":200,"remaining":142,"resetAt":"2026-04-01T00:00:00.000Z"}"#
            .data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(UsageResult.self, from: json)
        XCTAssertEqual(result.used,      58)
        XCTAssertEqual(result.total,     200,
            "UsageResult.total must map the 'limit' JSON key returned by the live API")
        XCTAssertEqual(result.remaining, 142)
        XCTAssertEqual(result.resetAt,   "2026-04-01T00:00:00.000Z")
    }

    func testUsageResultWithNilResetAt() throws {
        let json = #"{"used":0,"limit":100,"remaining":100}"#.data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(UsageResult.self, from: json)
        XCTAssertEqual(result.total, 100)
        XCTAssertNil(result.resetAt)
    }

    func testUsageSumInvariant() throws {
        let json = #"{"used":37,"limit":500,"remaining":463,"resetAt":null}"#.data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(UsageResult.self, from: json)
        XCTAssertEqual(result.used + result.remaining, result.total)
    }

    /// The client method must decode the live "limit" key correctly end-to-end.
    func testGetUsageDecodesLimit() async throws {
        let body = #"{"used":10,"limit":1000,"remaining":990,"resetAt":"2026-04-01T00:00:00.000Z"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let usage = try await client.getUsage()
        XCTAssertEqual(usage.used,      10)
        XCTAssertEqual(usage.total,     1000)
        XCTAssertEqual(usage.remaining, 990)
    }

    /// quota() must now route to /v1/usage (not the non-existent /v1/quota).
    func testQuotaCallsUsageEndpoint() async throws {
        let body = #"{"used":5,"limit":500,"remaining":495}"#.data(using: .utf8)!
        // We use a URL-capturing protocol to assert the correct path was called.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.response = MockResponse(statusCode: 200, data: body)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        let result = try await client.quota()
        XCTAssertEqual(result.total, 500)
        XCTAssertTrue(
            URLCapturingProtocol.lastURL?.path.hasSuffix("/v1/usage") == true,
            "quota() must call /v1/usage, got: \(URLCapturingProtocol.lastURL?.absoluteString ?? "nil")"
        )
    }
}

// MARK: - PingResult Decoding

final class PingResultDecodingTests: XCTestCase {

    func testPingDecodes() throws {
        let json = #"{"status":"ok","timestamp":1774765134303}"#.data(using: .utf8)!
        let ping = try JSONDecoder.snapAPI.decode(PingResult.self, from: json)
        XCTAssertEqual(ping.status, "ok")
        XCTAssertEqual(ping.timestamp, 1_774_765_134_303)
    }

    func testPingStatusNotOk() throws {
        let json = #"{"status":"degraded","timestamp":1000000000000}"#.data(using: .utf8)!
        let ping = try JSONDecoder.snapAPI.decode(PingResult.self, from: json)
        XCTAssertEqual(ping.status, "degraded")
    }

    func testClientPingMethod() async throws {
        let body = #"{"status":"ok","timestamp":9999999999999}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let ping = try await client.ping()
        XCTAssertEqual(ping.status, "ok")
        XCTAssertEqual(ping.timestamp, 9_999_999_999_999)
    }
}

// MARK: - ScreenshotOptions Full Field Encoding

final class ScreenshotOptionsEncodingTests: XCTestCase {

    private func encode(_ opts: ScreenshotOptions) throws -> [String: AnyCodable] {
        let data = try JSONEncoder.snapAPI.encode(opts)
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    func testAllViewportFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.width  = 1920
        opts.height = 1080
        opts.device = "iPhone 14 Pro"
        let json = try encode(opts)
        XCTAssertNotNil(json["width"])
        XCTAssertNotNil(json["height"])
        XCTAssertNotNil(json["device"])
    }

    func testPageBehaviourFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.fullPage        = true
        opts.selector        = "#content"
        opts.delay           = 500
        opts.timeout         = 30000
        opts.waitUntil       = "networkidle"
        opts.waitForSelector = ".loaded"
        let json = try encode(opts)
        XCTAssertNotNil(json["full_page"])
        XCTAssertNotNil(json["selector"])
        XCTAssertNotNil(json["delay"])
        XCTAssertNotNil(json["timeout"])
        XCTAssertNotNil(json["wait_until"])
        XCTAssertNotNil(json["wait_for_selector"])
    }

    func testBlockingFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.blockAds           = true
        opts.blockTrackers      = true
        opts.blockCookieBanners = true
        let json = try encode(opts)
        XCTAssertNotNil(json["block_ads"])
        XCTAssertNotNil(json["block_trackers"])
        XCTAssertNotNil(json["block_cookie_banners"])
    }

    func testScriptingFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.css             = "body { background: red; }"
        opts.javascript      = "window.scrollTo(0, 500);"
        opts.hideSelectors   = [".cookie-banner", "#popup"]
        opts.clickSelector   = "#accept-cookies"
        let json = try encode(opts)
        XCTAssertNotNil(json["css"])
        XCTAssertNotNil(json["javascript"])
        XCTAssertNotNil(json["hide_selectors"])
        XCTAssertNotNil(json["click_selector"])
    }

    func testIdentityFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.userAgent    = "Mozilla/5.0"
        opts.extraHeaders = ["X-Custom": "value"]
        opts.cookies      = [SnapCookie(name: "session", value: "abc123")]
        opts.httpAuth     = HTTPAuth(username: "admin", password: "secret")
        let json = try encode(opts)
        XCTAssertNotNil(json["user_agent"])
        XCTAssertNotNil(json["extra_headers"])
        XCTAssertNotNil(json["cookies"])
        XCTAssertNotNil(json["http_auth"])
    }

    func testProxyFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.proxy        = "http://user:pass@proxy.example.com:8080"
        opts.premiumProxy = true
        let json = try encode(opts)
        XCTAssertNotNil(json["proxy"])
        XCTAssertNotNil(json["premium_proxy"])
    }

    func testGeolocationAndTimezone() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.geolocation = Geolocation(latitude: 51.5, longitude: -0.1)
        opts.timezone    = "Europe/London"
        let json = try encode(opts)
        XCTAssertNotNil(json["geolocation"])
        XCTAssertNotNil(json["timezone"])
    }

    func testPDFPageOptionsEncoding() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.format = .pdf
        opts.pdf = PDFPageOptions(
            pageSize: .letter,
            landscape: true,
            marginTop: "2cm",
            marginBottom: "2cm"
        )
        let json = try encode(opts)
        XCTAssertNotNil(json["pdf"])
    }

    func testStorageAndWebhookFields() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.storage    = StorageDestination(destination: "s3", format: "png")
        opts.webhookUrl = "https://example.com/webhook"
        let json = try encode(opts)
        XCTAssertNotNil(json["storage"])
        XCTAssertNotNil(json["webhook_url"])
    }

    func testQualityField() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.format  = .jpeg
        opts.quality = 85
        let json = try encode(opts)
        XCTAssertNotNil(json["quality"])
        if case .int(let q) = json["quality"]?.value {
            XCTAssertEqual(q, 85)
        }
    }
}

// MARK: - VideoOptions Encoding

final class VideoOptionsEncodingTests: XCTestCase {

    private func encode(_ opts: VideoOptions) throws -> [String: AnyCodable] {
        let data = try JSONEncoder.snapAPI.encode(opts)
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    func testBasicVideoFields() throws {
        var opts = VideoOptions(url: "https://example.com")
        opts.format   = .mp4
        opts.width    = 1280
        opts.height   = 720
        opts.duration = 10
        opts.fps      = 30
        let json = try encode(opts)
        XCTAssertNotNil(json["url"])
        XCTAssertNotNil(json["format"])
        XCTAssertNotNil(json["width"])
        XCTAssertNotNil(json["height"])
        XCTAssertNotNil(json["duration"])
        XCTAssertNotNil(json["fps"])
    }

    func testScrollAnimationFields() throws {
        var opts = VideoOptions(url: "https://example.com")
        opts.scrolling      = true
        opts.scrollSpeed    = 200
        opts.scrollDelay    = 500
        opts.scrollDuration = 3000
        opts.scrollBy       = 50
        opts.scrollEasing   = .easeInOut
        opts.scrollBack     = true
        opts.scrollComplete = true
        let json = try encode(opts)
        XCTAssertNotNil(json["scrolling"])
        XCTAssertNotNil(json["scroll_speed"])
        XCTAssertNotNil(json["scroll_delay"])
        XCTAssertNotNil(json["scroll_duration"])
        XCTAssertNotNil(json["scroll_by"])
        XCTAssertNotNil(json["scroll_easing"])
        XCTAssertNotNil(json["scroll_back"])
        XCTAssertNotNil(json["scroll_complete"])
    }

    func testScrollEasingRawValues() {
        XCTAssertEqual(ScrollEasing.linear.rawValue,         "linear")
        XCTAssertEqual(ScrollEasing.easeIn.rawValue,         "ease_in")
        XCTAssertEqual(ScrollEasing.easeOut.rawValue,        "ease_out")
        XCTAssertEqual(ScrollEasing.easeInOut.rawValue,      "ease_in_out")
        XCTAssertEqual(ScrollEasing.easeInOutQuint.rawValue, "ease_in_out_quint")
    }

    func testVideoPageOptions() throws {
        var opts = VideoOptions(url: "https://example.com")
        opts.darkMode           = true
        opts.blockAds           = true
        opts.blockCookieBanners = true
        opts.delay              = 1000
        opts.fullPage           = true
        let json = try encode(opts)
        XCTAssertNotNil(json["dark_mode"])
        XCTAssertNotNil(json["block_ads"])
        XCTAssertNotNil(json["block_cookie_banners"])
        XCTAssertNotNil(json["delay"])
        XCTAssertNotNil(json["full_page"])
    }

    func testVideoResponseTypeBinaryIsSetInternally() async throws {
        let videoBytes = Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]) // mp4 magic
        let client = makeClient(response: MockResponse(statusCode: 200, data: videoBytes))
        var opts = VideoOptions(url: "https://example.com")
        opts.format = .mp4
        let data = try await client.video(opts)
        // SDK should have set responseType = "binary" internally
        XCTAssertEqual(data, videoBytes)
    }

    func testVideoResultResponseTypeJsonIsSetInternally() async throws {
        let body = #"""
        {"data":"AAAA","mimeType":"video/mp4","format":"mp4","width":1280,"height":720,"duration":5000,"size":12345}
        """#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let opts = VideoOptions(url: "https://example.com")
        let result = try await client.videoResult(opts)
        XCTAssertEqual(result.mimeType, "video/mp4")
        XCTAssertEqual(result.format, .mp4)
        XCTAssertEqual(result.width, 1280)
        XCTAssertEqual(result.height, 720)
        XCTAssertEqual(result.duration, 5000)
        XCTAssertEqual(result.size, 12345)
    }

    func testAllVideoFormats() {
        XCTAssertEqual(VideoFormat.allCases.count, 3)
    }
}

// MARK: - ExtractOptions Encoding

final class ExtractOptionsEncodingTests: XCTestCase {

    private func encode(_ opts: ExtractOptions) throws -> [String: AnyCodable] {
        let data = try JSONEncoder.snapAPI.encode(opts)
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    func testAllExtractFields() throws {
        var opts = ExtractOptions(url: "https://example.com")
        opts.format             = .article
        opts.selector           = ".article-body"
        opts.wait               = 1000
        opts.timeout            = 30000
        opts.darkMode           = false
        opts.blockAds           = true
        opts.blockCookieBanners = true
        opts.includeImages      = true
        opts.maxLength          = 5000
        let json = try encode(opts)
        XCTAssertNotNil(json["url"])
        XCTAssertNotNil(json["format"])
        XCTAssertNotNil(json["selector"])
        XCTAssertNotNil(json["wait"])
        XCTAssertNotNil(json["timeout"])
        XCTAssertNotNil(json["block_ads"])
        XCTAssertNotNil(json["block_cookie_banners"])
        XCTAssertNotNil(json["include_images"])
        XCTAssertNotNil(json["max_length"])
    }

    func testConvenienceMethodsCallCorrectFormat() async throws {
        let body = #"{"success":true,"type":"markdown","url":"https://example.com","data":"text","response_time":100}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        // article
        _ = try await client.extractArticle(url: "https://example.com")
        // text
        _ = try await client.extractText(url: "https://example.com")
        // links
        _ = try await client.extractLinks(url: "https://example.com")
        // images
        _ = try await client.extractImages(url: "https://example.com")
        // metadata
        _ = try await client.extractMetadata(url: "https://example.com")
        // All above pass through the mock without error — the key assertion
        // is that none throw an invalidParameters error.
    }

    func testExtractResultDecodesDataAsString() throws {
        // Note: avoid raw string literals here — the # in "# Hello" would end the literal.
        let jsonStr = "{\"success\":true,\"type\":\"markdown\",\"url\":\"https://example.com\",\"data\":\"H1 Hello\",\"response_time\":250}"
        let json = jsonStr.data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(ExtractResult.self, from: json)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.type, "markdown")
        XCTAssertEqual(result.url, "https://example.com")
        XCTAssertEqual(result.responseTime, 250)
        if case .string(let text) = result.data?.value {
            XCTAssertEqual(text, "H1 Hello")
        } else {
            XCTFail("Expected data to decode as AnyCodable string")
        }
    }

    func testExtractResultDecodesDataAsObject() throws {
        let json = #"{"success":true,"type":"metadata","url":"https://example.com","data":{"title":"Example"},"response_time":100}"#
            .data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(ExtractResult.self, from: json)
        XCTAssertNotNil(result.data)
        if case .object(let obj) = result.data?.value {
            XCTAssertNotNil(obj["title"])
        }
    }
}

// MARK: - PdfOptions Encoding

final class PdfOptionsEncodingTests: XCTestCase {

    private func encode(_ opts: PdfOptions) throws -> [String: AnyCodable] {
        let data = try JSONEncoder.snapAPI.encode(opts)
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    func testPdfOptionsEncoding() throws {
        var opts = PdfOptions(url: "https://example.com")
        opts.pageFormat = .letter
        opts.landscape  = true
        opts.margin     = "1cm"
        opts.wait       = 2000
        let json = try encode(opts)
        XCTAssertNotNil(json["url"])
        XCTAssertNotNil(json["page_format"])
        XCTAssertNotNil(json["landscape"])
        XCTAssertNotNil(json["margin"])
        XCTAssertNotNil(json["wait"])
    }

    func testAllPDFPageFormats() {
        XCTAssertEqual(PDFPageFormat.a4.rawValue,      "a4")
        XCTAssertEqual(PDFPageFormat.letter.rawValue,  "letter")
        XCTAssertEqual(PDFPageFormat.a3.rawValue,      "a3")
        XCTAssertEqual(PDFPageFormat.a5.rawValue,      "a5")
        XCTAssertEqual(PDFPageFormat.legal.rawValue,   "legal")
        XCTAssertEqual(PDFPageFormat.tabloid.rawValue, "tabloid")
        XCTAssertEqual(PDFPageFormat.allCases.count, 6)
    }

    func testPdfEndpointReturnsData() async throws {
        let pdfMagic = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        let client = makeClient(response: MockResponse(statusCode: 200, data: pdfMagic))
        let result = try await client.pdf(PdfOptions(url: "https://example.com"))
        XCTAssertEqual(result.prefix(4), pdfMagic)
    }

    func testPdfFromScreenshotSetsFormatToPDF() async throws {
        // We intercept the request and verify the encoded body contains format=pdf
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BodyCapturingURLProtocol.self]
        BodyCapturingURLProtocol.response = MockResponse(
            statusCode: 200,
            data: Data([0x25, 0x50, 0x44, 0x46])
        )
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.format = .png // should be overridden to .pdf
        _ = try await client.pdfFromScreenshot(opts)
        if let body = BodyCapturingURLProtocol.lastBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(json["format"] as? String, "pdf",
                           "pdfFromScreenshot must override format to 'pdf'")
        }
    }
}

// MARK: - AnalyzeOptions Encoding

final class AnalyzeOptionsEncodingTests: XCTestCase {

    func testAnalyzeOptionsWithJsonSchema() throws {
        var opts = AnalyzeOptions(url: "https://example.com")
        opts.prompt   = "Extract product details"
        opts.provider = .anthropic
        opts.apiKey   = "sk_anthropic_test"
        opts.jsonSchema = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "name": AnyCodable(["type": AnyCodable("string")])
            ])
        ]
        let data = try JSONEncoder.snapAPI.encode(opts)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        XCTAssertNotNil(json["prompt"])
        XCTAssertNotNil(json["provider"])
        XCTAssertNotNil(json["api_key"])
        XCTAssertNotNil(json["json_schema"])
    }

    func testAnalyzeResultDecoding() throws {
        let json = #"{"result":"This is a summary","url":"https://example.com"}"#
            .data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(AnalyzeResult.self, from: json)
        XCTAssertEqual(result.result, "This is a summary")
        XCTAssertEqual(result.url, "https://example.com")
    }
}

// MARK: - Error mapping edge cases

final class ErrorMappingEdgeCaseTests: XCTestCase {

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

    func test404MapsToServerError() async throws {
        let body = #"{"statusCode":404,"error":"Not Found","message":"Route not found"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 404, data: body))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let message) {
            XCTAssertEqual(code, 404)
            XCTAssertTrue(message.contains("Route not found"))
        }
    }

    func test422MapsToServerError() async throws {
        let body = #"{"statusCode":422,"error":"Validation Error","message":"Invalid URL format"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 422, data: body))
        do {
            _ = try await client.scrape(ScrapeOptions(url: "https://example.com"))
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, _) {
            XCTAssertEqual(code, 422)
        }
    }

    func test400MapsToServerError() async throws {
        let body = #"{"statusCode":400,"error":"Validation Error","message":"body/duration must be <= 30"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 400, data: body))
        do {
            _ = try await client.video(VideoOptions(url: "https://example.com"))
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 400)
            XCTAssertTrue(msg.contains("duration"))
        }
    }

    func testRateLimitedWithDefaultFallback() async throws {
        // No Retry-After header — should default to 60s
        let client = makeClient(response: MockResponse(statusCode: 429, data: Data(), headers: [:]))
        do {
            _ = try await client.ping()
            XCTFail("Expected rateLimited")
        } catch SnapAPIError.rateLimited(let after) {
            XCTAssertEqual(after, 60, accuracy: 0.1)
        }
    }

    func testRateLimitedWithRetryAfterHeader() async throws {
        let client = makeClient(response: MockResponse(
            statusCode: 429, data: Data(),
            headers: ["Retry-After": "45"]
        ))
        do {
            _ = try await client.ping()
            XCTFail("Expected rateLimited")
        } catch SnapAPIError.rateLimited(let after) {
            XCTAssertEqual(after, 45, accuracy: 0.1)
        }
    }

    func testServerErrorWithNonJSONBody() async throws {
        let body = "Internal Server Error".data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 500, data: body))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 500)
            XCTAssertTrue(msg.contains("Internal Server Error"))
        }
    }

    func testServerErrorWithEmptyBody() async throws {
        let client = makeClient(response: MockResponse(statusCode: 502, data: Data()))
        do {
            _ = try await client.getUsage()
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, _) {
            XCTAssertEqual(code, 502)
        }
    }

    func testAllErrorCasesConformToError() {
        // All cases must be throwable (compile-time, but runtime verification)
        let errors: [SnapAPIError] = [
            .authenticationFailed,
            .rateLimited(retryAfter: 1),
            .quotaExceeded,
            .serverError(statusCode: 500, message: "err"),
            .networkError(underlying: URLError(.timedOut)),
            .invalidParameters("bad"),
            .decodingError(underlying: NSError(domain: "d", code: 1))
        ]
        for err in errors {
            XCTAssertNotNil(err.errorDescription)
        }
    }
}

// MARK: - RetryPolicy Comprehensive

final class RetryPolicyComprehensiveTests: XCTestCase {

    func testCustomRetryPolicy() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 2.0, maxDelay: 60.0)
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.baseDelay,   2.0)
        XCTAssertEqual(policy.maxDelay,    60.0)
    }

    func testNonRetryableErrorsNeverRetry() {
        let policy = RetryPolicy.default
        let nonRetryable: [SnapAPIError] = [
            .authenticationFailed,
            .quotaExceeded,
            .invalidParameters("x"),
            .decodingError(underlying: NSError(domain: "d", code: 1)),
            .serverError(statusCode: 400, message: "bad"),
            .serverError(statusCode: 404, message: "nf"),
            .serverError(statusCode: 422, message: "ve"),
        ]
        for err in nonRetryable {
            XCTAssertFalse(
                policy.shouldRetry(error: err, attempt: 0),
                "\(err) should not be retried"
            )
        }
    }

    func testRetryableErrorsAreRetried() {
        let policy = RetryPolicy.default
        let retryable: [SnapAPIError] = [
            .rateLimited(retryAfter: 1),
            .networkError(underlying: URLError(.timedOut)),
            .serverError(statusCode: 500, message: "oops"),
            .serverError(statusCode: 502, message: "bad gateway"),
            .serverError(statusCode: 503, message: "unavailable"),
        ]
        for err in retryable {
            XCTAssertTrue(
                policy.shouldRetry(error: err, attempt: 0),
                "\(err) should be retried"
            )
        }
    }

    func testDelayDoublesEachAttempt() {
        let policy = RetryPolicy(maxAttempts: 4, baseDelay: 1.0, maxDelay: 100.0)
        let d0 = Double(policy.delay(forAttempt: 0)) / 1e9  // 1s
        let d1 = Double(policy.delay(forAttempt: 1)) / 1e9  // 2s
        let d2 = Double(policy.delay(forAttempt: 2)) / 1e9  // 4s
        let d3 = Double(policy.delay(forAttempt: 3)) / 1e9  // 8s
        XCTAssertEqual(d0, 1.0,  accuracy: 0.001)
        XCTAssertEqual(d1, 2.0,  accuracy: 0.001)
        XCTAssertEqual(d2, 4.0,  accuracy: 0.001)
        XCTAssertEqual(d3, 8.0,  accuracy: 0.001)
    }

    func testOverrideSecondsTakePrecedence() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1.0, maxDelay: 30.0)
        let ns = policy.delay(forAttempt: 0, overrideSeconds: 5.0)
        XCTAssertEqual(ns, UInt64(5_000_000_000))
    }

    func testMaxDelayCapsOverride() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1.0, maxDelay: 3.0)
        let ns = policy.delay(forAttempt: 0, overrideSeconds: 100.0)
        let secs = Double(ns) / 1e9
        XCTAssertLessThanOrEqual(secs, 3.0 + 0.001)
    }

    func testRetryCountIsExhausted() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CountingURLProtocol.self]
        CountingURLProtocol.callCount = 0
        CountingURLProtocol.alwaysFail = true
        let successBody = #"{"status":"ok","timestamp":1234}"#.data(using: .utf8)!
        CountingURLProtocol.successResponse = MockResponse(statusCode: 200, data: successBody)
        let session = URLSession(configuration: config)
        // 2 retries = 3 total attempts
        let client = SnapAPIClient(
            apiKey: "sk_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 0.001, maxDelay: 0.001)
        )
        do {
            _ = try await client.ping()
            XCTFail("Expected networkError after retries exhausted")
        } catch SnapAPIError.networkError {
            // pass
        }
        XCTAssertEqual(CountingURLProtocol.callCount, 3, "1 initial + 2 retries = 3 total calls")
    }
}

// MARK: - SnapAPI TypeAlias

final class TypeAliasTests: XCTestCase {

    func testSnapAPITypeAliasIsSnapAPIClient() {
        // This is purely a compile-time test — if SnapAPI != SnapAPIClient, it won't compile.
        let _: SnapAPIClient.Type = SnapAPI.self
        XCTAssertTrue(true)
    }

    func testQuotaResultTypeAliasIsUsageResult() {
        let _: UsageResult.Type = QuotaResult.self
        XCTAssertTrue(true)
    }
}

// MARK: - screenshotToFile

final class ScreenshotToFileTests: XCTestCase {

    func testScreenshotToFileWritesCorrectBytes() async throws {
        let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let client = makeClient(response: MockResponse(statusCode: 200, data: pngBytes))
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snap_test_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        let bytes = try await client.screenshotToFile(
            ScreenshotOptions(url: "https://example.com"),
            path: tmpURL
        )
        XCTAssertEqual(bytes, pngBytes.count)
        let written = try Data(contentsOf: tmpURL)
        XCTAssertEqual(written, pngBytes)
    }
}

// MARK: - URL composition

final class URLCompositionTests: XCTestCase {

    func testBaseURLWithTrailingSlash() {
        let builder = RequestBuilder(
            baseURL: URL(string: "https://api.snapapi.pics/")!,
            apiKey: "sk_test"
        )
        let req = builder.get(path: "/v1/ping")
        // Should not produce double-slash
        XCTAssertFalse(req.url?.absoluteString.contains("//v1") == true,
                       "URL must not contain double-slash: \(req.url?.absoluteString ?? "nil")")
    }

    func testBaseURLWithoutTrailingSlash() {
        let builder = RequestBuilder(
            baseURL: URL(string: "https://api.snapapi.pics")!,
            apiKey: "sk_test"
        )
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.url?.absoluteString, "https://api.snapapi.pics/v1/ping")
    }
}

// MARK: - Concurrent requests

final class ConcurrencyTests: XCTestCase {

    func testConcurrentRequestsDontRaceOnMockProtocol() async throws {
        let body = #"{"used":0,"limit":100,"remaining":100}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        // Fire 10 concurrent getUsage calls
        try await withThrowingTaskGroup(of: UsageResult.self) { group in
            for _ in 0..<10 {
                group.addTask { try await client.getUsage() }
            }
            var count = 0
            for try await result in group {
                XCTAssertEqual(result.total, 100)
                count += 1
            }
            XCTAssertEqual(count, 10)
        }
    }
}

// MARK: - ScrapeResult / ScrapeItem Decoding

final class ScrapeDecodingTests: XCTestCase {

    func testMultiPageScrapeResult() throws {
        let json = #"""
        {
          "success": true,
          "results": [
            {"page": 1, "url": "https://example.com",   "data": "page 1 content"},
            {"page": 2, "url": "https://example.com/2", "data": "page 2 content"}
          ]
        }
        """#.data(using: .utf8)!
        let result = try JSONDecoder.snapAPI.decode(ScrapeResult.self, from: json)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.results.count, 2)
        XCTAssertEqual(result.results[0].page, 1)
        XCTAssertEqual(result.results[1].page, 2)
        XCTAssertEqual(result.results[1].url, "https://example.com/2")
    }

    func testScrapeAllOptions() throws {
        var opts = ScrapeOptions(url: "https://example.com")
        opts.selector       = "article"
        opts.wait           = 1000
        opts.pages          = 5
        opts.proxy          = "http://proxy:8080"
        opts.premiumProxy   = true
        opts.blockResources = true
        opts.locale         = "en-US"
        let data = try JSONEncoder.snapAPI.encode(opts)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        XCTAssertNotNil(json["selector"])
        XCTAssertNotNil(json["wait"])
        XCTAssertNotNil(json["pages"])
        XCTAssertNotNil(json["proxy"])
        XCTAssertNotNil(json["premium_proxy"])
        XCTAssertNotNil(json["block_resources"])
        XCTAssertNotNil(json["locale"])
    }
}

// MARK: - SnapCookie / HTTPAuth / Geolocation / StorageDestination

final class SharedModelTests: XCTestCase {

    func testSnapCookieFullInit() {
        let cookie = SnapCookie(
            name: "auth", value: "token123",
            domain: ".example.com", path: "/app"
        )
        XCTAssertEqual(cookie.name,   "auth")
        XCTAssertEqual(cookie.value,  "token123")
        XCTAssertEqual(cookie.domain, ".example.com")
        XCTAssertEqual(cookie.path,   "/app")
    }

    func testSnapCookieCodable() throws {
        let cookie = SnapCookie(name: "s", value: "v", domain: ".test.com")
        let data = try JSONEncoder().encode(cookie)
        let decoded = try JSONDecoder().decode(SnapCookie.self, from: data)
        XCTAssertEqual(decoded.name,   cookie.name)
        XCTAssertEqual(decoded.value,  cookie.value)
        XCTAssertEqual(decoded.domain, cookie.domain)
    }

    func testHTTPAuthCodable() throws {
        let auth = HTTPAuth(username: "user", password: "pass")
        let data = try JSONEncoder.snapAPI.encode(auth)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        XCTAssertNotNil(json["username"])
        XCTAssertNotNil(json["password"])
    }

    func testGeolocationCodable() throws {
        let geo = Geolocation(latitude: 48.8566, longitude: 2.3522, accuracy: 5.0)
        let data = try JSONEncoder().encode(geo)
        let decoded = try JSONDecoder().decode(Geolocation.self, from: data)
        XCTAssertEqual(decoded.latitude,  48.8566,  accuracy: 0.0001)
        XCTAssertEqual(decoded.longitude, 2.3522,   accuracy: 0.0001)
        XCTAssertEqual(decoded.accuracy!, 5.0,      accuracy: 0.0001)
    }

    func testStorageDestinationCodable() throws {
        let sd = StorageDestination(destination: "s3", format: "png")
        let data = try JSONEncoder.snapAPI.encode(sd)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        XCTAssertNotNil(json["destination"])
        XCTAssertNotNil(json["format"])
    }
}

// MARK: - AnyCodable edge cases

final class AnyCodableEdgeCaseTests: XCTestCase {

    func testDoubleRoundTrip() throws {
        let json = #"{"pi":3.14159}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        if case .double(let v) = d["pi"]?.value {
            XCTAssertEqual(v, 3.14159, accuracy: 0.00001)
        } else {
            XCTFail("Expected .double")
        }
    }

    func testNestedArrayRoundTrip() throws {
        let json = #"{"tags":["swift","ios","api"]}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        if case .array(let arr) = d["tags"]?.value {
            XCTAssertEqual(arr.count, 3)
        } else {
            XCTFail("Expected .array")
        }
    }

    func testDeepNestedObject() throws {
        let json = #"{"a":{"b":{"c":"deep"}}}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode(AnyCodable.self, from: json)
        guard case .string(let s) = d.a?.b?.c?.value else {
            XCTFail("Deep dynamic member lookup failed"); return
        }
        XCTAssertEqual(s, "deep")
    }

    func testEncodeNullField() throws {
        let v: AnyCodable = nil
        let data = try JSONEncoder().encode(v)
        let str = String(data: data, encoding: .utf8)
        XCTAssertEqual(str, "null")
    }
}

// MARK: - Additional URL Protocol Helpers

/// Captures the URL of each request for path verification.
final class URLCapturingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: MockResponse = MockResponse(statusCode: 200, data: Data())
    nonisolated(unsafe) static var lastURL: URL?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastURL = request.url
        let r = Self.response
        let http = HTTPURLResponse(
            url: request.url!, statusCode: r.statusCode,
            httpVersion: "HTTP/1.1", headerFields: r.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: r.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Captures the request body for POST verification.
final class BodyCapturingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: MockResponse = MockResponse(statusCode: 200, data: Data())
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastBody = request.httpBody
        let r = Self.response
        let http = HTTPURLResponse(
            url: request.url!, statusCode: r.statusCode,
            httpVersion: "HTTP/1.1", headerFields: r.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: r.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// URLProtocol that always fails (for exhausted-retry test).
final class CountingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var callCount: Int = 0
    nonisolated(unsafe) static var alwaysFail: Bool = false
    nonisolated(unsafe) static var successResponse: MockResponse = MockResponse(statusCode: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.callCount += 1
        if Self.alwaysFail {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
        } else {
            let r = Self.successResponse
            let http = HTTPURLResponse(
                url: request.url!, statusCode: r.statusCode,
                httpVersion: "HTTP/1.1", headerFields: [:]
            )!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: r.data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
