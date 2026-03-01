import XCTest
@testable import SnapAPI

final class SnapAPITests: XCTestCase {

    func testScreenshotOptionsRequiresSource() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.screenshot(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testScrapeOptionsRequiresURL() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.scrape(ScrapeOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExtractOptionsRequiresURL() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.extract(ExtractOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnalyzeOptionsRequiresURL() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.analyze(AnalyzeOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAPIErrorIsRetryable() {
        let retryable = SnapAPIError.apiError(code: "RATE_LIMITED", message: "Too many requests", statusCode: 429)
        XCTAssertTrue(retryable.isRetryable)

        let notRetryable = SnapAPIError.apiError(code: "INVALID_PARAMS", message: "Bad request", statusCode: 400)
        XCTAssertFalse(notRetryable.isRetryable)
    }

    func testAnyCodableDecoding() throws {
        let json = """
        {"string":"hello","number":42,"bool":true,"nested":{"key":"val"}}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(decoded["string"]?.value as? String, "hello")
        XCTAssertEqual(decoded["number"]?.value as? Int, 42)
    }
}
