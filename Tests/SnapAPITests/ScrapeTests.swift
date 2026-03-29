import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Scrape Tests

final class ScrapeTests: XCTestCase {

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

    // MARK: - Scrape

    func testScrapeRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.scrape(ScrapeOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
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

    // MARK: - Extract

    func testExtractRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.extract(ExtractOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }

    func testSuccessfulExtract() async throws {
        let bodyStr = "{\"success\":true,\"type\":\"markdown\",\"url\":\"https://example.com\",\"data\":\"Hello\",\"response_time\":250}"
        let body = bodyStr.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let result = try await client.extract(ExtractOptions(url: "https://example.com"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.type, "markdown")
        XCTAssertEqual(result.responseTime, 250)
    }

    func testExtractFormatRawValues() {
        XCTAssertEqual(ExtractFormat.markdown.rawValue, "markdown")
        XCTAssertEqual(ExtractFormat.article.rawValue,  "article")
        XCTAssertEqual(ExtractFormat.text.rawValue,     "text")
        XCTAssertEqual(ExtractFormat.html.rawValue,     "html")
        XCTAssertEqual(ExtractFormat.links.rawValue,    "links")
        XCTAssertEqual(ExtractFormat.images.rawValue,   "images")
        XCTAssertEqual(ExtractFormat.metadata.rawValue, "metadata")
    }

    func testExtractFormatAllCases() {
        let allFormats: [ExtractFormat] = [
            .markdown, .text, .html, .article, .links, .images, .metadata, .structured
        ]
        XCTAssertEqual(ExtractFormat.allCases.count, allFormats.count)
    }

    // MARK: - Analyze

    func testAnalyzeRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.analyze(AnalyzeOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
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

    func testAnalyzeProviderRawValues() {
        XCTAssertEqual(AnalyzeProvider.openai.rawValue,    "openai")
        XCTAssertEqual(AnalyzeProvider.anthropic.rawValue, "anthropic")
        XCTAssertEqual(AnalyzeProvider.google.rawValue,    "google")
    }

    func testAnalyzeOptionsInit() {
        var opts = AnalyzeOptions(url: "https://example.com")
        opts.prompt   = "Summarize"
        opts.provider = .openai
        XCTAssertEqual(opts.url, "https://example.com")
        XCTAssertEqual(opts.prompt, "Summarize")
        XCTAssertEqual(opts.provider, .openai)
    }

    // MARK: - Usage / Quota / Ping

    func testSuccessfulUsageDecoding() async throws {
        let body = #"{"used":120,"limit":1000,"remaining":880}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let usage = try await client.getUsage()
        XCTAssertEqual(usage.used,      120)
        XCTAssertEqual(usage.total,     1000)
        XCTAssertEqual(usage.remaining, 880)
    }

    func testSuccessfulPing() async throws {
        let body = #"{"status":"ok","timestamp":1710000000000}"#.data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 200, data: body))
        let ping = try await client.ping()
        XCTAssertEqual(ping.status, "ok")
        XCTAssertEqual(ping.timestamp, 1_710_000_000_000)
    }
}
