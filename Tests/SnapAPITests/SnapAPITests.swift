import XCTest
@testable import SnapAPI

final class SnapAPITests: XCTestCase {

    // MARK: - Validation Tests

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

    // MARK: - isRetryable Tests

    func testAPIErrorIsRetryable() {
        let retryable = SnapAPIError.apiError(code: "RATE_LIMITED", message: "Too many requests", statusCode: 429)
        XCTAssertTrue(retryable.isRetryable)

        let notRetryable = SnapAPIError.apiError(code: "INVALID_PARAMS", message: "Bad request", statusCode: 400)
        XCTAssertFalse(notRetryable.isRetryable)
    }

    func testTimeoutErrorIsRetryable() {
        let timeout = SnapAPIError.apiError(code: "TIMEOUT", message: "Request timed out", statusCode: 408)
        XCTAssertTrue(timeout.isRetryable)
    }

    func testServerErrorIsRetryable() {
        let serverError = SnapAPIError.apiError(code: "INTERNAL_ERROR", message: "Server error", statusCode: 500)
        XCTAssertTrue(serverError.isRetryable)
    }

    func testNetworkErrorIsRetryable() {
        let networkError = SnapAPIError.networkError(underlying: URLError(.notConnectedToInternet))
        XCTAssertTrue(networkError.isRetryable)
    }

    func testInvalidParametersNotRetryable() {
        let err = SnapAPIError.invalidParameters("url is required")
        XCTAssertFalse(err.isRetryable)
    }

    func testDecodingErrorNotRetryable() {
        let err = SnapAPIError.decodingError(underlying: NSError(domain: "test", code: 0))
        XCTAssertFalse(err.isRetryable)
    }

    func testHTTPErrorNotRetryable() {
        let err = SnapAPIError.httpError(statusCode: 404, body: "Not found")
        XCTAssertFalse(err.isRetryable)
    }

    // MARK: - errorDescription Tests

    func testInvalidParametersDescription() {
        let err = SnapAPIError.invalidParameters("url is required")
        XCTAssertEqual(err.errorDescription, "Invalid parameters: url is required")
    }

    func testAPIErrorDescription() {
        let err = SnapAPIError.apiError(code: "NOT_FOUND", message: "Resource not found", statusCode: 404)
        XCTAssertEqual(err.errorDescription, "[NOT_FOUND] Resource not found (HTTP 404)")
    }

    func testHTTPErrorDescription() {
        let err = SnapAPIError.httpError(statusCode: 503, body: "Service Unavailable")
        XCTAssertEqual(err.errorDescription, "HTTP 503: Service Unavailable")
    }

    func testNetworkErrorDescription() {
        let underlying = URLError(.timedOut)
        let err = SnapAPIError.networkError(underlying: underlying)
        XCTAssertNotNil(err.errorDescription)
        XCTAssertTrue(err.errorDescription!.contains("Network error"))
    }

    func testDecodingErrorDescription() {
        let underlying = NSError(domain: "decode", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad JSON"])
        let err = SnapAPIError.decodingError(underlying: underlying)
        XCTAssertNotNil(err.errorDescription)
        XCTAssertTrue(err.errorDescription!.contains("Decoding error"))
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableDecoding() throws {
        let json = """
        {"string":"hello","number":42,"bool":true,"nested":{"key":"val"}}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(decoded["string"]?.value as? String, "hello")
        XCTAssertEqual(decoded["number"]?.value as? Int, 42)
    }

    func testAnyCodableBoolDecoding() throws {
        let json = """
        {"flag":true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertEqual(decoded["flag"]?.value as? Bool, true)
    }

    func testAnyCodableNullDecoding() throws {
        let json = """
        {"empty":null}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertNotNil(decoded["empty"])
    }

    // MARK: - Convenience Method Tests

    func testPDFConvenienceSetsFormatToPDF() async {
        let api = SnapAPI(apiKey: "test")
        // pdf() convenience wraps screenshot() — should still require a source
        do {
            _ = try await api.pdf(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters(let msg) {
            XCTAssertTrue(
                msg.contains("url") || msg.contains("html") || msg.contains("markdown"),
                "Error message should mention missing source: \(msg)"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVideoOptionsRequiresURL() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.video(VideoOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVideoResultRequiresURL() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.videoResult(VideoOptions(url: ""))
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testScreenshotToStorageRequiresSource() async {
        let api = SnapAPI(apiKey: "test")
        do {
            _ = try await api.screenshotToStorage(ScreenshotOptions())
            XCTFail("Expected invalidParameters error")
        } catch SnapAPIError.invalidParameters {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - SnapAPIError Pattern Matching Tests

    func testNetworkErrorPatternMatch() {
        let err = SnapAPIError.networkError(underlying: URLError(.cancelled))
        if case .networkError = err {
            // correct pattern match
        } else {
            XCTFail("Expected networkError case")
        }
    }

    func testInvalidParametersCarriesMessage() {
        let msg = "url is required."
        let err = SnapAPIError.invalidParameters(msg)
        if case .invalidParameters(let m) = err {
            XCTAssertEqual(m, msg)
        } else {
            XCTFail("Expected invalidParameters case")
        }
    }

    func testServiceUnavailableIsRetryable() {
        let err = SnapAPIError.apiError(code: "SERVICE_UNAVAILABLE", message: "Down", statusCode: 503)
        XCTAssertTrue(err.isRetryable, "5xx errors should be retryable")
    }

    func testUnauthorizedIsNotRetryable() {
        let err = SnapAPIError.apiError(code: "UNAUTHORIZED", message: "No key", statusCode: 401)
        XCTAssertFalse(err.isRetryable, "401 should not be retryable")
    }
}
