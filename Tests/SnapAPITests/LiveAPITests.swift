import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Live API Integration Tests
//
// These tests call the real SnapAPI backend. They are skipped automatically
// when the SNAPAPI_TEST_KEY environment variable is not set, so CI stays fast.
//
// To run locally:
//   SNAPAPI_TEST_KEY=sk_live_... swift test --filter LiveAPITests

final class LiveAPITests: XCTestCase {

    // MARK: - Helpers

    private var apiKey: String {
        ProcessInfo.processInfo.environment["SNAPAPI_TEST_KEY"] ?? ""
    }

    /// Skip the test if no live key is configured.
    private func requireLiveKey() throws -> SnapAPIClient {
        guard !apiKey.isEmpty else {
            throw XCTSkip("Set SNAPAPI_TEST_KEY to run live integration tests.")
        }
        return SnapAPIClient(apiKey: apiKey, retryPolicy: .never)
    }

    // MARK: - Ping

    func testLivePingReturnsOk() async throws {
        let client = try requireLiveKey()
        let ping = try await client.ping()
        XCTAssertEqual(ping.status, "ok")
        XCTAssertGreaterThan(ping.timestamp, 0)
    }

    // MARK: - Usage

    func testLiveUsageDecodes() async throws {
        let client = try requireLiveKey()
        let usage = try await client.getUsage()
        XCTAssertGreaterThanOrEqual(usage.used, 0)
        XCTAssertGreaterThan(usage.total, 0)
        XCTAssertGreaterThanOrEqual(usage.remaining, 0)
        XCTAssertEqual(usage.used + usage.remaining, usage.total,
                       "used + remaining must equal total")
    }

    // MARK: - Screenshot

    func testLiveScreenshotPNGReturnsImageData() async throws {
        let client = try requireLiveKey()
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.format = .png
        opts.width  = 800
        opts.height = 600
        let data = try await client.screenshot(opts)
        // PNG magic bytes: 89 50 4E 47
        XCTAssertGreaterThan(data.count, 1000)
        XCTAssertEqual(data.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testLiveScreenshotJPEGReturnsImageData() async throws {
        let client = try requireLiveKey()
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.format = .jpeg
        opts.width  = 640
        let data = try await client.screenshot(opts)
        // JPEG magic bytes: FF D8 FF
        XCTAssertGreaterThan(data.count, 1000)
        XCTAssertEqual(data.prefix(3), Data([0xFF, 0xD8, 0xFF]))
    }

    func testLiveScreenshotFromHTML() async throws {
        let client = try requireLiveKey()
        let opts = ScreenshotOptions(html: "<h1 style='color:red'>Hello SnapAPI</h1>")
        let data = try await client.screenshot(opts)
        XCTAssertGreaterThan(data.count, 1000)
    }

    func testLiveScreenshotFullPage() async throws {
        let client = try requireLiveKey()
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.fullPage = true
        opts.format   = .png
        let data = try await client.screenshot(opts)
        XCTAssertGreaterThan(data.count, 1000)
    }

    func testLiveScreenshotDarkMode() async throws {
        let client = try requireLiveKey()
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.darkMode = true
        let data = try await client.screenshot(opts)
        XCTAssertGreaterThan(data.count, 100)
    }

    func testLiveScreenshotToFile() async throws {
        let client = try requireLiveKey()
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snapapi_test_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        let opts = ScreenshotOptions(url: "https://example.com")
        let bytes = try await client.screenshotToFile(opts, path: tmpURL)
        XCTAssertGreaterThan(bytes, 1000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpURL.path))
    }

    // MARK: - Scrape

    func testLiveScrapeReturnsContent() async throws {
        let client = try requireLiveKey()
        let opts = ScrapeOptions(url: "https://example.com")
        let result = try await client.scrape(opts)
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.results.isEmpty)
        XCTAssertEqual(result.results[0].page, 1)
        XCTAssertFalse(result.results[0].data.isEmpty)
        XCTAssertEqual(result.results[0].url, "https://example.com")
    }

    func testLiveScrapeWithSelector() async throws {
        let client = try requireLiveKey()
        var opts = ScrapeOptions(url: "https://example.com")
        opts.selector = "h1"
        let result = try await client.scrape(opts)
        XCTAssertTrue(result.success)
    }

    // MARK: - Extract

    func testLiveExtractMarkdown() async throws {
        let client = try requireLiveKey()
        let result = try await client.extractMarkdown(url: "https://example.com")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.type, "markdown")
        if case .string(let text) = result.data?.value {
            XCTAssertFalse(text.isEmpty)
        }
        XCTAssertGreaterThan(result.responseTime, 0)
    }

    func testLiveExtractText() async throws {
        let client = try requireLiveKey()
        let result = try await client.extractText(url: "https://example.com")
        XCTAssertTrue(result.success)
    }

    func testLiveExtractAllFormats() async throws {
        let client = try requireLiveKey()
        // We only call markdown (cheapest) but verify the API handles it
        var opts = ExtractOptions(url: "https://example.com")
        opts.format = .markdown
        opts.maxLength = 500
        let result = try await client.extract(opts)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.url, "https://example.com")
    }
}
