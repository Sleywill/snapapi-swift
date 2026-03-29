import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Screenshot Tests

final class ScreenshotTests: XCTestCase {

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

    // MARK: - Validation

    func testScreenshotRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.screenshot(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
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

    func testScreenshotAcceptsMarkdown() {
        let opts = ScreenshotOptions(markdown: "# Hello")
        XCTAssertNil(opts.url)
        XCTAssertNotNil(opts.markdown)
    }

    func testScreenshotToStorageRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.screenshotToStorage(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }

    // MARK: - Happy path

    func testSuccessfulScreenshotReturnsData() async throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        let client = makeClient(response: MockResponse(statusCode: 200, data: imageBytes))
        let result = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
        XCTAssertEqual(result, imageBytes)
    }

    func testScreenshotWithHTMLSource() async throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let client = makeClient(response: MockResponse(statusCode: 200, data: imageBytes))
        let result = try await client.screenshot(ScreenshotOptions(html: "<h1>Hello</h1>"))
        XCTAssertEqual(result, imageBytes)
    }

    func testScreenshotWithMarkdownSource() async throws {
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let client = makeClient(response: MockResponse(statusCode: 200, data: imageBytes))
        let result = try await client.screenshot(ScreenshotOptions(markdown: "# Hello"))
        XCTAssertEqual(result, imageBytes)
    }

    // MARK: - Options encoding

    func testScreenshotOptionsEncoding() throws {
        var opts = ScreenshotOptions(url: "https://example.com")
        opts.fullPage = true
        opts.darkMode = true
        opts.format = .jpeg
        opts.width = 1280
        opts.blockAds = true

        let data = try JSONEncoder.snapAPI.encode(opts)
        let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        // The encoder uses snake_case
        XCTAssertNotNil(json["full_page"])
        XCTAssertNotNil(json["dark_mode"])
        XCTAssertNotNil(json["block_ads"])
    }

    func testScreenshotFormatRawValues() {
        XCTAssertEqual(ScreenshotFormat.png.rawValue,  "png")
        XCTAssertEqual(ScreenshotFormat.jpeg.rawValue, "jpeg")
        XCTAssertEqual(ScreenshotFormat.webp.rawValue, "webp")
        XCTAssertEqual(ScreenshotFormat.avif.rawValue, "avif")
        XCTAssertEqual(ScreenshotFormat.pdf.rawValue,  "pdf")
    }

    // MARK: - Error responses

    func testUnauthorizedScreenshot() async throws {
        let client = makeClient(response: MockResponse(statusCode: 401, data: Data()))
        do {
            _ = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
            XCTFail("Expected authenticationFailed error")
        } catch SnapAPIError.authenticationFailed {
            // pass
        }
    }

    func testRateLimitedScreenshot() async throws {
        let client = makeClient(response: MockResponse(
            statusCode: 429,
            data: Data(),
            headers: ["Retry-After": "30"]
        ))
        do {
            _ = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
            XCTFail("Expected rateLimited error")
        } catch SnapAPIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 30)
        }
    }

    func testServerErrorScreenshot() async throws {
        let body = #"{"error":"INTERNAL_ERROR","message":"Something went wrong"}"#
            .data(using: .utf8)!
        let client = makeClient(response: MockResponse(statusCode: 500, data: body))
        do {
            _ = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
            XCTFail("Expected serverError")
        } catch SnapAPIError.serverError(let code, let msg) {
            XCTAssertEqual(code, 500)
            XCTAssertTrue(msg.contains("Something went wrong"))
        }
    }

    // MARK: - PDF

    func testPdfRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.pdf(PdfOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }

    func testPdfFromScreenshotRequiresSource() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.pdfFromScreenshot(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }

    // MARK: - Video

    func testVideoRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.video(VideoOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }

    func testVideoResultRequiresURL() async {
        let client = SnapAPIClient(apiKey: "test")
        do {
            _ = try await client.videoResult(VideoOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // pass
        } catch {
            XCTFail("Expected SnapAPIError.invalidParameters but got \(error)")
        }
    }
}
